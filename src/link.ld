ENTRY(entry)

SECTIONS {
    . = 0x1000;
    .text : {
		KEEP(*(.entry))
        *(.text)
    }

    .rodata : {
         *(.rodata, .rodata.*)
    }

	.data : {
		*(.data)
	}

	.bss : {
		*(.bss)
	}
}
