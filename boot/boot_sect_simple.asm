[org 0x7c00]
KERNEL_OFFSET equ 0x1000; the same we used when linking the kernel
	mov [BOOT_DRIVE], dl

	mov bp, 0x9000 ; set the stack 
	mov sp, bp

	mov bx, MSG_REAL_MODE
	call print_str

	call load_kernel
	call switch_to_pm
	jmp $


%include  "boot/print_string.asm"
%include  "boot/disk_load.asm"
%include  "boot/gdt.asm"
%include  "boot/switch_to_pm.asm"
%include  "boot/print_str_pm.asm"

[bits 16]
load_kernel:	
	mov bx, MSG_LOAD_KERNEL
	call print_str

	mov bx, KERNEL_OFFSET
	mov dh, 15
	mov dl, [BOOT_DRIVE]
	call disk_load
	ret


[bits 32]
BEGIN_PM:
	mov ebx, MSG_PROT_MODE
	call print_string_pm
	call KERNEL_OFFSET ; gives control to the kernel
	jmp $ ; loop infinitely


; global variables 
MSG_REAL_MODE:
	db "Started in 16-bit Real Mode", 0

MSG_PROT_MODE:
	db "Successfully landed in 32-bit protected mode", 0
	
BOOT_DRIVE:
	db 0

MSG_LOAD_KERNEL:
	dw "Loading Kernel!"	

; zero padding and magic bios number
times 510-($-$$) db 0
dw 0xaa55

