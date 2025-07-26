type:
	pusha ; macro
	
	push ds
	push es

	add si, 5
	mov ah, 0x7
	int 0x21
	test di, di
	jz .not_exist
	mov ah, 0x8
	mov dl, [drive]
	lea bx, [0x4000]
	mov es, bx
	xor bx, bx
	int 0x21

	mov ax, es
	mov ds, ax

	xor ah, ah
	mov bl, 0xf
	lea si, [0x0]
	int 0x21

	jmp .done
.not_exist:
	mov ax, cs
	mov ds, ax
	
	xor ah, ah
	mov bl, 0x4
	lea si, [error_not_file]
	int 0x21
.done:
	pop es
	pop ds

	popa ; macro
	jmp line