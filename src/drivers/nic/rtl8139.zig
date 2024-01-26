const pci = @import("../pci/pci.zig");
const std = @import("std");
const log = std.log.scoped(.rtl8139);
const Port = @import("arch").io.Port;
const interrupt = @import("../../interrupts/interrupts.zig");
const net = @import("net");
const Nic = net.Nic;
const arch = @import("arch");
const pic = @import("../../interrupts/pic.zig");

const RX_BUFFER_SIZE = 8192 + 16;
const TX_BUFFER_SIZE = 1792;

const ROK: u16 = 0b1; // Receive Ok
const TOK: u32 = 0b100; // Transmit Ok

pub var rx_buffer: [RX_BUFFER_SIZE]u8 = .{0} ** RX_BUFFER_SIZE;
var tx_buffer: [4][TX_BUFFER_SIZE]u8 = .{.{0} ** TX_BUFFER_SIZE} ** 4;

const Self = @This();
var device: Self = undefined;

registers: struct {
    mac: [6]Port(u8),
    tx_cmds: [tx_buffer.len]Port(u32),
    tx_addrs: [tx_buffer.len]Port(u32),
    config1: Port(u8),
    rx_addr: Port(u32), // receive buffer address
    capr: Port(u16), // current address of packet read
    cba: Port(u16), // current buffer address
    cmd: Port(u8), // command register
    imr: Port(u16), // interrupt mask register
    isr: Port(u16), // interrupt service register
    tx_config: Port(u32),
    rx_config: Port(u32),
},

active_tx_idx: u8 = 0,
mac_address: [6]u8,
irq_line: usize,

pub fn init(pci_dev: *const pci.Device) !*Self {
    pci_dev.enableBusMastering();
    const iobase = switch (pci_dev.read_bar(0)) {
        .Io => |val| val,
        else => return error.InvalidBarValue,
    };
    device = Self{
        .registers = .{
            .mac = [6]Port(u8){
                Port(u8).init(iobase + 0x0),
                Port(u8).init(iobase + 0x1),
                Port(u8).init(iobase + 0x2),
                Port(u8).init(iobase + 0x3),
                Port(u8).init(iobase + 0x4),
                Port(u8).init(iobase + 0x5),
            },
            .tx_cmds = .{
                Port(u32).init(iobase + 0x10),
                Port(u32).init(iobase + 0x14),
                Port(u32).init(iobase + 0x18),
                Port(u32).init(iobase + 0x1c),
            },
            .tx_addrs = .{
                Port(u32).init(iobase + 0x20),
                Port(u32).init(iobase + 0x24),
                Port(u32).init(iobase + 0x28),
                Port(u32).init(iobase + 0x2c),
            },
            .config1 = Port(u8).init(iobase + 0x52),
            .rx_addr = Port(u32).init(iobase + 0x30),
            .capr = Port(u16).init(iobase + 0x38),
            .cba = Port(u16).init(iobase + 0x3A),
            .cmd = Port(u8).init(iobase + 0x37),
            .imr = Port(u16).init(iobase + 0x3C),
            .isr = Port(u16).init(iobase + 0x3E),
            .tx_config = Port(u32).init(iobase + 0x40),
            .rx_config = Port(u32).init(iobase + 0x44),
        },
        .mac_address = undefined,
        .irq_line = undefined,
    };

    log.info("iobase: 0x{x}", .{iobase});
    device.registers.config1.write(0); // power on device
    device.registers.cmd.write(0x10); // reset
    while (device.registers.cmd.read() & 0x10 != 0) {} // wait until reset finishes
    log.info("device reset", .{});

    device.registers.rx_addr.write(@intFromPtr(&rx_buffer)); // send rx buffer address
    device.registers.imr.write(0x5); // activate transmit ok and receive ok interrupts

    device.registers.rx_config.write(0xe); // configure receive buffer. Accepts all packets. AB+AM+APM+AAP

    // Enable transmitter and receiver to allow packets in/out
    device.registers.cmd.write(0xC); // Sets Transmitter Enabled and Receiver Enabled bits to high

    const interrupt_line = pci_dev.location.readConfig(.InterruptLine);
    interrupt.setIrqHandler(interrupt_line, @intFromPtr(&rtl8139_int_handler));
    device.irq_line = interrupt_line;

    device.mac_address = device.read_mac_addr();
    device.print_mac_addr();
    return &device;
}

pub fn transmit_packet(self: *Self, buffer_addr: u32, len: u32) !void {
    if (len > 1792) {
        return error.PacketTooLarge;
    }
    while (self.registers.tx_cmds[self.active_tx_idx].read() & 0x2000 != 0x2000) {} // wait until previous DMA operation is done, if in process.

    self.registers.tx_addrs[self.active_tx_idx].write(buffer_addr);
    const cmd = 0x1FFF & len; // sets own bit to start DMA operation
    self.registers.tx_cmds[self.active_tx_idx].write(cmd);

    self.active_tx_idx = @intCast((self.active_tx_idx + 1) % tx_buffer.len);
}

pub fn receive_packet(self: *Self) ?[]u8 {
    const is_empty = self.registers.cmd.read() & 1 == 1;
    if (is_empty) return null;
    const offset = (@as(u32, @intCast(self.registers.capr.read())) + 16) & 0xFFFF;
    const packet = rx_buffer[offset..];

    const header = @as(*u16, @alignCast(@ptrCast(packet[0..2]))).*;
    const length = @as(*u16, @alignCast(@ptrCast(packet[2..4]))).*;
    if (header & ROK != ROK) {
        @panic("packet not ok");
    }
    const data = packet[4..length];
    const capr: u16 = ((@as(u16, @intCast(offset)) + length + 7) & ~@as(u16, 3)) - 16;
    self.registers.capr.write(capr);
    return data;
}

fn receive(ctx: *anyopaque) ?[]u8 {
    var self: *Self = @ptrCast(@alignCast(ctx));
    return self.receive_packet();
}

fn transmit(ctx: *anyopaque, addr: u32, len: u32) anyerror!void {
    var self: *Self = @ptrCast(@alignCast(ctx));
    return self.transmit_packet(addr, len);
}

pub fn setNic(self: *Self) *Nic {
    return Nic.init(
        self,
        &.{
            .receive_packet = receive,
            .transmit_packet = transmit,
        },
        self.mac_address,
    );
}

fn print_mac_addr(self: *Self) void {
    const write = @import("arch").serial.write;
    write("[rtl8139] mac address: ", .{});
    // for (0..6) |idx| {
    //     const val: u8 = @truncate(self.mac_address >> @intCast((5 - idx) * 8));
    //     if (idx == 5) write("{x}\n", .{val}) else write("{x}::", .{val});
    // }

    for (0..6) |idx| {
        const val = self.mac_address[idx];
        if (idx == 5) write("{x}\n", .{val}) else write("{x}::", .{val});
    }
}

fn read_mac_addr(self: *const Self) [6]u8 {
    var mac: [6]u8 = undefined;
    for (self.registers.mac, 0..) |m, idx| {
        mac[idx] = m.read();
    }
    return mac;
}

const rtl8139_int_handler = arch.interrupt_handler(interrupt_handler);
export fn interrupt_handler(_: arch.thread.Context) usize {
    const status = device.registers.isr.read();
    device.registers.isr.write(0x5);
    if (status & TOK == TOK) {
        log.info("(int) transmit ok", .{});
    }
    if (status & ROK == ROK) {
        log.info("(int) received packet", .{});
        net.IFACE.proecssEthernetFrame();
    }

    pic.sendEoi(device.irq_line);
    return 0;
}

fn read_packet(self: *Self) void {
    _ = self;
}
