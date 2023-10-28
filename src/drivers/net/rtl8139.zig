const pci = @import("../pci/pci.zig");
const std = @import("std");
const log = std.log.scoped(.rtl8139);
const Port = @import("arch").io.Port;
const interrupt = @import("../../interrupts/interrupts.zig");

const RX_BUFFER_SIZE = 8192 + 16;
const TX_BUFFER_SIZE = 8192 + 16;

var rx_buffer: [RX_BUFFER_SIZE]u8 = .{0} ** RX_BUFFER_SIZE;
var tx_buffer: [4][TX_BUFFER_SIZE]u8 = .{.{0} ** TX_BUFFER_SIZE} ** 4;

const Self = @This();
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

pub fn init(device: *pci.Device) !Self {
    const iobase = switch (device.read_bar(0)) {
        .Io => |val| val,
        else => return error.InvalidBarValue,
    };
    var dev = Self{
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
    };

    log.info("iobase: 0x{x}", .{iobase});
    dev.registers.config1.write(0); // power on device
    dev.registers.cmd.write(0x10); // reset
    while (dev.registers.cmd.read() & 0x10 != 0) {} // wait until reset finishes
    log.info("device reset", .{});

    dev.registers.rx_addr.write(@intFromPtr(&rx_buffer)); // send rx buffer address
    dev.registers.imr.write(0x5); // activate transmit ok and receive ok interrupts

    dev.registers.rx_config.write(0xf); // configure receive buffer. Accepts all packets. AB+AM+APM+AAP

    // Enable transmitter and receiver to allow packets in/out
    dev.registers.cmd.write(0xC); // Sets Transmitter Enabled and Receiver Enabled bits to high

    const interrupt_line = device.location.readConfig(.InterruptLine);
    _ = interrupt_line;
    // interrupt.setIrqHandler(interrupt_line, interrupt_handler);

    return dev;
}

pub fn transmit(self: *Self) void {
    _ = self;
}

pub fn receive(self: *Self) void {
    _ = self;
}

fn inc_transmit_idx(self: *Self) void {
    if (self.active_tx_idx == 3) {
        self.active_tx_idx = 0;
    } else {
        self.active_tx_idx += 1;
    }
}

export fn interrupt_handler(ctx: interrupt.Context) void {
    _ = ctx;
}
