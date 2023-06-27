SECTIONS {
    . = 0x100000;
	kernel_start = .; 
    .text : {
		KEEP(*(.entry))
        *(.text)
        *(.text*)
    }

    .rodata : {
         *(.rodata)
         *(.rodata*)
    }

	.data : {
		*(.data)
		*(.data*)
	}

	.bss :  {
		*(.bss)
		*(.bss*)
	}


	kernel_end = .;
}
