print_fn:
	pusha ; pushes all registers to stack
	mov ah, 0x0e ; BIOS teletype mode
	int 0x10 ; cause interrupt code 0x10 to print the character
	popa ; restores register state from stack
	ret


print_str:
	mov al, [bx]
	cmp al , 0
	jne p
	jmp end
	p:
		call print_fn 
		add bx, 1
		jmp print_str
	end:
	ret

