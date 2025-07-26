help:
	xor ah, ah
	mov bl, 0xf
	lea si, [str_commands]
	int 0x21
.find_next_string:
	mov al, [si]
	inc si
	test al, al
	jnz .find_next_string
	mov al, [si]
	test al, al
	jz line
	int 0x21
	jmp .find_next_string