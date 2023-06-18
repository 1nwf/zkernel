SECTIONS {
    . = 0x1000;
	kernel_start = .; 
    .text : {
		KEEP(*(.entry))
        *(.text*)
    }

    .rodata : ALIGN(4K) {
         *(.rodata, .rodata.*)
    }

	.data : ALIGN(4K) {
		*(.data)
	}

	.bss : ALIGN(4K) {
		*(.bss)
	}


	kernel_end = .;
}
