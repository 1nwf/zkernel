ENTRY(entry)

SECTIONS {
    . = 0x1000;
    .text :  {
		KEEP(*(.entry))
        *(.text)
    }

    .rodata.str1.1 : {
        *(.rodata)
    }
}