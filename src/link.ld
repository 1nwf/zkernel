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
		kernel_stack_start = ALIGN(4);
		. += 0x4000;
		kernel_stack_end = ALIGN(4);
	}

	kernel_end = .;
}
