const PICM_COMMAND = 0x20; // master pci
const PICS_COMMAND = 0xA0; // slave pci
const PICM_DATA = PICM_COMMAND + 1;
const PICS_DATA = PICS_COMMAND + 1;

const EOI: u8 = 0x20; // end of interrupt

const io = @import("../io.zig");
const out = io.out;
const in = io.in;
const write = @import("../drivers/vga.zig").write;

// if interrupt was issued by master pci, eoi needs to be only sent to master
// if it was from the slave pci, both neet be sent eoi
pub fn sendEoi(irq: usize) void {
    if (irq >= 8) {
        out(PICS_COMMAND, EOI);
    }
    out(PICM_COMMAND, EOI);
}

pub fn remapPic(master_offset: u8, slave_offset: u8) void {
    // start init sequence in cascade mode
    // makes pics wait for 3 initialization words on its data ports
    out(PICM_COMMAND, @as(u8, 0x11));
    out(PICS_COMMAND, @as(u8, 0x11));
    // set master and slave offsets
    out(PICM_DATA, master_offset);
    out(PICS_DATA, slave_offset);
    // notify slave and master of each other
    out(PICM_DATA, @as(u8, 0x04));
    out(PICS_DATA, @as(u8, 0x02));

    out(PICM_DATA, @as(u8, 0x01));
    out(PICS_DATA, @as(u8, 0x01));

    // enable IRQs
    out(PICS_DATA, @as(u8, 0x0));
    out(PICS_DATA, @as(u8, 0x0));
}
