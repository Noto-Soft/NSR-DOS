dir:
	pusha ; macro
	push ds

	xor ah, ah
	inc ah
	mov al, endl
	mov bl, 0xf
	int 0x21
	dec ah
	lea si, [msg_directory_of]
	int 0x21
	inc ah
	; holds drive letter conveniently
	mov al, [msg_command]
	int 0x21
	mov al, endl
	int 0x21
	int 0x21

	xor ax, ax
	mov ds, ax
	lea di, [0x800]
	xor ah, ah
	mov bl, 0xf
	xor cx, cx
	xor dx, dx
.loop:
	mov al, [di]
	cmp al, 0
	je .done
	add di, 4
	mov al, [di]
	cmp al, 0
	je .skip

	mov si, di
	int 0x21
	mov ah, 0x1
	mov al, " "
	int 0x21

	mov ah, 0xd
	mov cl, [di-2]
	add cl, 1
	shr cl, 1
	int 0x21
	add dx, cx

	mov ah, 0x1
	mov al, "k"
	int 0x21
	mov al, "b"
	int 0x21

	mov al, endl
	int 0x21
.skip:
	dec di
	mov al, [di]
	xor ah, ah
	add di, ax
	inc di
	jmp .loop
.done:
	pop ds

	xor ah, ah
	mov bl, 0xf
	lea si, [msg_sectors_used]
	int 0x21

	mov ah, 0xd
	mov cx, dx
	int 0x21

	mov ah, 0x1
	mov al, "k"
	int 0x21
	mov al, "b"
	int 0x21

	mov ah, 0x1
	mov al, endl
	int 0x21
	int 0x21

	popa ; macro
	jmp line