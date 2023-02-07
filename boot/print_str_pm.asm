[bits 32]

VIDEO_MEMORY equ 0xb8000
WHITE_ON_BLACK equ 0x0f

print_string_pm:
	pusha 
	mov edx, VIDEO_MEMORY ; set edx to start of vid memory

print_str_loop:
	mov al, [ebx] ; store the char at ebx in al
	mov ah, WHITE_ON_BLACK

	cmp al, 0
	je print_str_done
	mov [edx], ax ; store char and attributes at current char cell

	add ebx, 1
	add edx, 2 ; move to next character cell

	jmp print_str_loop

print_str_done: 
	popa 
	ret

