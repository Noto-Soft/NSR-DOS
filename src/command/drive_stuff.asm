a:
	mov al, "A"
	xor dl, dl
	jmp set_drive

b:
	mov al, "B"
	mov dl, 1

set_drive:
	xor ah, ah
	mov bl, 0xf
	lea si, [msg_insert_diskette]
	int 0x21
	inc ah
	int 0x21
	dec ah
	lea si, [msg_insert_diskette2]
	int 0x21
	push ax
	xor ah, ah
	int 0x16
	pop ax
	pusha ; macro
	push es
	mov ah, 0x8
	int 0x13
	jc drive_empty
	pop es
	popa ; macro
	mov byte [drive], dl
	mov byte [msg_command], al
	mov ah, 0x9
	int 0x21
	jmp dir

drive_empty:
	xor ah, ah
	mov bl, 0x4
	lea si, [error_drive_missing]
	int 0x21
	jmp line

drive_invalid_fs:
	mov al, 0x5
	int 0xff

floppy_error:
	mov al, 0x4
	int 0xff