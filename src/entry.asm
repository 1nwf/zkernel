extern kmain
extern kernel_stack_end
global _start ; kernel elf entry point

section .multiboot
MAGIC equ 0xE85250D6
ARCH equ 0 ; x86 i386
HEADER_LEN equ 0
FLAGS equ 0x00000002 
CHECKSUM equ 1<<32 - (MAGIC + ARCH)
TAGS equ 0

; multiboot header
header_start:
align 8
	dd MAGIC 
	dd ARCH
	dd header_end - header_start
  dd - (MAGIC + ARCH + (header_end - header_start))
 ;end tag
  dw 0; type
  dw 0; flags
  dd 8; size
header_end:


section .text
_start:
	mov esp, kernel_stack_end
	xor ebp, ebp ; set ebp to zero to signal last frame when walking the stack
	push ebp
	push ebx
	call kmain
	jmp $
