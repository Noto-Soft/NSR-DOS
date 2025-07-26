del:
	pusha ; macro

	mov ah, 0x7
	add si, 4
	mov dl, [drive]
	int 0x21
	test di, di
	jz .not_exist
	mov ah, 0xa
	int 0x21

	popa ; macro
	jmp line
.not_exist:
	xor ah, ah
	mov bl, 0x4
	lea si, [error_not_file]
	int 0x21

	popa
	jmp line