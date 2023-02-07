; reading from disk
disk_load: 
	push dx ; store dx on stack so that we can later recall how many sectors were requested to be read.
	mov ah, 0x02 ; BIOS read sector function

	mov al, dh ; read DH sectors from the starting point
	; mov dl, 0x00 ; Read drive 0 (first floppy drive) 
	mov ch, 0x00 ; select cylindar 
	mov dh, 0x00 
	mov cl, 0x02 ; starting from the 2nd sector. the secter after the boot sector.

	int 0x13; issue bios interrupt to make the read
	jc disk_error ; jc = jump if carry flag was set

	pop dx 
	cmp dh, al ; if AL (sectors read) != DH (requested to be read)
	jne disk_error	; display error

	ret


disk_error:
	mov bx, DISK_ERROR_MSG
	call print_str
	jmp $ 

; ----------------


DISK_ERROR_MSG: db "Disk read error!", 0
