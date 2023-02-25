; GDT
gdt_start:

gdt_null: ; the (mandatory) null descriptor
	dd 0x0 ; dd = define doubel word = 32 bits or 4 bytes
	dd 0x0

gdt_code: ; the code segment descriptor
	dw 0xffff ; Limit: bits 0-15 
	dw 0x0 ; Base: bits 0-15
	db 0x0 ; Base: bits 16-23
	db 10011010b ; 1st  flags, type flags
	db 11001111b ; 2nd flags, Limit: bits 16-19
	db 0x0 ; Base: bits 24-31
		
gdt_data: ; the data segment descriptor
	dw 0xffff
	dw 0x0 
	db 0x0
	db 10010010b
	db 11001111b
	db 0x0
	
gdt_end: ; the reason for this is so we can have the assembler calculate the size of the gdt for the gdt descriptor


gdt_descriptor:
	dw gdt_end - gdt_start - 1 ; size of gdt always less one of the true size
	dd gdt_start ; start address of the GDT

	

; define constants for the gdt segment descriptor offsets, which are what segment offset registers contain.
; These are the indexes into the gdt descriptor table
; 0x0 -> NULL; 0x08 -> CODE; 0x10 -> DATA
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
