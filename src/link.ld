SECTIONS {
    . = 1M;
	kernel_start = .; 
    .text : {
		KEEP(*(.multiboot))
        *(.text*)
    }

    .rodata : {
         *(.rodata*)
    }

	.data : {
		*(.data)
	}

	.bss :  {
		*(.bss*)
		kernel_stack_start = ALIGN(16);
		. += 0x4000;
		kernel_stack_end = ALIGN(16);
	}

	kernel_end = .;
}
