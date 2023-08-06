const PICM_COMMAND = 0x20; // master pci
const PICS_COMMAND = 0xA0; // slave pci
const PICM_DATA = PICM_COMMAND + 1;
const PICS_DATA = PICS_COMMAND + 1;

const EOI: u8 = 0x20; // end of interrupt

const arch = @import("arch");
const out = arch.out;
const in = arch.in;
const write = @import("../drivers/vga.zig").write;

// if interrupt was issued by master pci, eoi needs to be only sent to master
// if it was from the slave pci, both neet be sent eoi
pub fn sendEoi(irq: usize) void {
    if (irq >= 8) {
        out(PICS_COMMAND, EOI);
    }
    out(PICM_COMMAND, EOI);
}

// ICW1 -> PIC Command Register
// -----------------------
// Bit Num. | Description
// ---------|-------------
//    0     | If set, pic knows that it will recieve 4 ICWs (initialization control words)
//    1     | If set, it tells the pic that that there is only one pic. Otherwise, there is another pic in the system
//    2     | ignored on x86
//    3     | if set, pic operates in level triggered mode (signal is maintained until interrupt is handled by the cpu), otherwise, it operates in edge triggered mode (a device sends a single pulse through the irq line and then restores it to prev. state)
//    4     | if set, it tells the pic that is currently being initiliazed, otherwise, the pic is initialized and can start handling interrupt requests
//    5-7   | ignored. set to 0.
// -----------------------

// ICW2 -> PIC Data Register
// used to set the base address of the pic irqs in the idt

// ICW3 -> PIC Data Register
// Master PIC : specifies which irq line is connected to the slave PIC
// Slave  PIC : bits 0 - 2 specify what irq line the master PIC uses to communicate with the Slave PIC. other bits not set.

// ICW3 -> PIC Data Register
// -----------------------
// Bit Num. | Description
// ---------|-------------
//    0     | If set, pic operates in 8086 mode
//    1     | If set, pic automatically sends eoi when an interrupt is acknowledged
//    2     | used when buffered mode is enabled. if set, buffer master, else buffer slave
//    3     | if set, buffered mode is enabled.
//    4     | is set, nested mode is enabled. disabled here.
//    5-7   | ignored. set to 0.
// -----------------------

pub fn remapPic(master_offset: u8, slave_offset: u8) void {
    // start init sequence in cascade mode
    // makes pics wait for 3 initialization words on its data ports

    out(PICM_COMMAND, @as(u8, 0x11));
    out(PICS_COMMAND, @as(u8, 0x11));
    // set master and slave offsets
    out(PICM_DATA, master_offset);
    out(PICS_DATA, slave_offset);
    // notify slave and master of each other
    out(PICM_DATA, @as(u8, 0x04)); // 0x0100. second bit is set which corresponds to irq 2
    out(PICS_DATA, @as(u8, 0x02)); // corresponds to irq 2 on slave PIC

    out(PICM_DATA, @as(u8, 0x01));
    out(PICS_DATA, @as(u8, 0x01));

    // enable IRQs
    out(PICS_DATA, @as(u8, 0x0));
    out(PICS_DATA, @as(u8, 0x0));
}
