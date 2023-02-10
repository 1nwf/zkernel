ENTRY(main)

SECTIONS {
    . = 0x1000;
    .text :  {
		KEEP(*(.entry))
        *(.text)
    }

}