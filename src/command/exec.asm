exec:
	pusha ; macro
	
	push ds
	push es

	mov ah, 0x7
	int 0x21
	test di, di
	jz .check_autofill
.after_autofill_check:
	mov dl, [drive]
	lea bx, [0x2800]
	mov ax, cs
	cmp bx, ax
	jne .after_error
	mov al, 1
	int 0xff
.after_error:
	mov ah, 0x8
	mov es, bx
	xor bx, bx
	int 0x21

	mov ax, [es:0x0]
	cmp ax, "AD"
	jne .unknown_format
	mov al, [es:0x2]
	cmp al, 0x2
	jne .unknown_format
	mov ax, [es:0x4]
	pusha ; macro
	push ds
	push es
	mov dl, [drive]
	lea bx, [.after]
	push cs
	push bx
	push es
	push ax
	retf
.after:
	pop es
	pop ds
	popa ; macro

	jmp .done
.not_exist:
	mov ax, cs
	mov ds, ax
	
	xor ah, ah
	mov bl, 0x4
	lea si, [error_not_command_or_file]
	int 0x21
.done:
	pop es
	pop ds

	popa ; macro
	jmp line
.unknown_format:
	mov al, 0x2
	int 0xff
.check_autofill:
	push si
.find_terminator_loop:
	inc si
	cmp byte [si-1], 0
	jne .find_terminator_loop
	mov word [si-1], ".E"
	mov word [si+1], "XE"
	pop si

	mov ah, 0x7
	int 0x21
	test di, di
	jz .not_exist

	jmp .after_autofill_check