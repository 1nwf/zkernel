section .smp_trampoline
extern kernel_stack_end
extern ap_start

[bits 16]
smp_trampoline:
	cli
	cld
	jmp 0:load_gdtr

gdt_start:
  dd 0x0
  dd 0x0
code32: 
	dw 0xffff ; Limit: bits 0-15 
	dw 0x0 ; Base: bits 0-15
	db 0x0 ; Base: bits 16-23
	db 10011010b ; 1st  flags, type flags
	db 11001111b ; 2nd flags, Limit: bites 16-19
	db 0x0 ; Base: bits 24-31
data32: 
	dw 0xffff
	dw 0x0 
	db 0x0
	db 10010010b
	db 11001111b
	db 0x0
gdt_end: 
gdt_descr:
  dw gdt_end - gdt_start - 1
  dd gdt_start

load_gdtr:
	lgdt [gdt_descr]
	mov eax, cr0
	or eax, 1
	mov cr0, eax
	jmp 8:pm_mode

[bits 32]
pm_mode:
	mov ax, 16
	mov ds, ax
	mov ss, ax
	mov esp, kernel_stack_end ; TODO: allocate dedicated stack
	xor ebp, ebp
	jmp 8:ap_start

