cls:
	mov ah, 0x6
	xor al, al
	mov bh, 0xf
	xor cx, cx
	mov dx, 0x184f
	int 0x10

	mov ah, 0xb
	xor dx, dx
	int 0x21

	jmp line