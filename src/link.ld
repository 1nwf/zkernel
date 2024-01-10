SECTIONS {
	. = 0x8000;

	.smp_trampoline : ALIGN(4K) {
		KEEP(*(.smp_trampoline))
	}

    . = 1M;
	kernel_start = .; 

    .text : ALIGN(4K) {
		KEEP(*(.multiboot))
        *(.text*)
    }

    .rodata : ALIGN(4K) {
         *(.rodata*)
    }

	.data : ALIGN(4K) {
		*(.data)
	}

	.bss : ALIGN(4K)  {
		*(.bss*)
		kernel_stack_start = ALIGN(4);
		. += 0x4000;
		kernel_stack_end = ALIGN(4);
	}

	kernel_end = ALIGN(4K);
}
