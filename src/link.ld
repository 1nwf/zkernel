ENTRY(main)
OUTPUT_FORMAT(elf64-x86-64)

SECTIONS {
    . = 0x1000;
    .text :  {
		KEEP(*(.entry))
        *(.text)
    }

}