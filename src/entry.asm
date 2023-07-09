extern main
extern kernel_stack_end
global _start ; kernel elf entry point

section .multiboot
MAGIC equ 0x1BADB002
FLAGS equ 0x00000003 
CHECKSUM equ -(MAGIC+FLAGS)

; multiboot header
header_start:
	dd MAGIC 
  dd FLAGS 
  dd CHECKSUM
header_end:


section .text
_start:
	mov esp, kernel_stack_end
	mov ebp, esp
	push ebx
	call main
	jmp $
