SECTIONS {
    . = 0x1000;
	kernel_start = .; 
    .text : {
		KEEP(*(.entry))
        *(.text)
        *(.text*)
    }

    .rodata : ALIGN(4) {
         *(.rodata)
         *(.rodata*)
    }

	.data : ALIGN(4) {
		*(.data)
		*(.data*)
	}

	.bss : ALIGN(4)  {
		*(.bss)
		*(.bss*)
	}


	kernel_end = .;
}
