bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "8086.inc"

db "AD"
db 2
db 0
dw start

drive: db 0

msg_directory_of: db "Directory of drive ", 0
msg_command: db "A>", 0
msg_sectors_used: db endl, "Kilobytes used: ", 0

str_commands: db "List of commands:", endl, 0
str_a: db "a:", 0
	db 0x9, " - Set drive to drive A: (drive #0)", endl, 0
str_b: db "b:", 0
	db 0x9, " - Set drive to drive B: (drive #1)", endl, 0
str_cat: db "cat", 0
	db 0x9, " - Alias for type (doesn't actually conCATenate)", endl, 0
str_cls: db "cls", 0
	db 0x9, " - Clear console output", endl, 0
str_del: db "del", 0
	db 0x9, " - Deletes a file from the disk directory", endl, 0
str_dir: db "dir", 0
	db 0x9, " - List files on the disk directory", endl, 0
str_help: db "help", 0
	db 0x9, " - List available commands and their functions", endl, 0
str_ls: db "ls", 0
	db 0x9, " - Alias for dir", endl, 0
str_type: db "type", 0
	db 0x9, " - Read a file out to the console", endl, 0
db 0

str_start: db "start", 0

error_not_command_or_file: db "Not a command nor an executable file", endl, 0
error_not_file: db "File does not exist", endl, 0
error_drive_missing: db "Disk is not inserted into the drive", endl, 0

buffer: times 112 db 0
BUFFER_END equ $
	; allow some extra space for .exe autofill
times 4 db 0
db 0
BUFFER_SPACE_END equ $

start:
	mov [drive], dl
	jmp main

strcmp:
	push si
	push di
.loop:
	mov al, [si]
	mov ah, [es:di]
	inc si
	inc di
	cmp al, ah
	jne .notequal
	test al, al
	jz .endofstring
	jmp .loop
.endofstring:
	xor ax, ax
	jmp .done
.notequal:
	mov ax, 1
	jmp .done
.done:
	pop di
	pop si
	ret

strcmp_until_di_end:
	push si
	push di
.loop:
	mov al, [si]
	mov ah, [di]
	inc si
	inc di
	test ah, ah
	jz .endofstring
	cmp al, ah
	jne .notequal
	jmp .loop
.endofstring:
	xor ax, ax
	jmp .done
.notequal:
	mov ax, 1
	jmp .done
.done:
	pop di
	pop si
	ret

strcmp_until_delimiter:
	push si
	push di
.loop:
	mov al, [si]
	mov ah, [di]
	inc si
	inc di
	cmp al, bl
	je .endofstring
	test al, al
	jz .endofstring
	cmp al, ah
	jne .notequal
	jmp .loop
.endofstring:
	xor ax, ax
	jmp .done
.notequal:
	mov ax, 1
	jmp .done
.done:
	pop di
	pop si
	ret

strcmp_dont_preserve_si:
	push di
.loop:
	mov al, [si]
	mov ah, [es:di]
	inc si
	inc di
	cmp al, ah
	jne .notequal
	test al, al
	jz .endofstring
	jmp .loop
.endofstring:
	xor ax, ax
	jmp .done
.notequal:
	mov ax, 1
	jmp .done
.done:
	pop di
	ret

case_up:
	push ax
	push si
	cld
.loop:
	lodsb

	test al, al
	jz .print
	cmp al, 'a'
	jb .loop
	cmp al, 'z'
	ja .loop

	sub al, 'a' - 'A'
	mov [si-1], al
	
	jmp .loop
.print:
	pop si
	pop ax
	ret

clear_buffer:
	push ax
	push di
	xor al, al
.loop:
	mov [di], al
	inc di
	cmp di, BUFFER_SPACE_END
	ja .done
	jmp .loop
.done:
	pop di
	pop ax
	ret

main:
	mov ax, cs
	mov ds, ax
	mov es, ax

	jmp dir

line:
	lea di, [buffer]
	call clear_buffer
	xor ah, ah
	mov bl, 0xf
	lea si, [msg_command]
	int 0x21
.loop:
	xor ah, ah
	int 0x16
	cmp al, 0xd
	je line_done
	cmp al, 0x8
	je .backspace
	cmp di, BUFFER_END
	jnb .loop
	mov ah, 0x1
	mov bl, 0xf
	int 0x21
	mov [di], al
	inc di
	mov byte [di], 0
	jmp .loop
.backspace:
	cmp di, buffer
	jna .loop
	mov ah, 0x1
	mov bl, 0xf
	int 0x21
	dec di
	mov byte [di], 0
	jmp .loop

line_done:
	mov ah, 0x1
	mov bl, 0xf
	mov al, 0xa
	int 0x21

	push di

	lea si, [buffer]

	lea di, [str_dir]
	call strcmp
	or al, al
	jz dir
	lea di, [str_ls]
	call strcmp
	or al, al
	jz dir

	lea di, [str_type]
	mov bl, " "
	call strcmp_until_delimiter
	or al, al
	jz type
	lea di, [str_cat]
	mov bl, " "
	call strcmp_until_delimiter
	or al, al
	jz cat

	lea di, [str_del]
	mov bl, " "
	call strcmp_until_delimiter
	or al, al
	jz del

	lea di, [str_help]
	call strcmp
	or al, al
	jz help

	lea di, [str_cls]
	call strcmp
	or al, al
	jz cls

	lea di, [str_a]
	call strcmp
	or al, al
	jz a

	lea di, [str_b]
	call strcmp
	or al, al
	jz b

	pop di

	cmp di, buffer
	je line

	jmp exec

dir:
	pusha ; macro
	push ds

	xor ah, ah
	inc ah
	mov al, 0xa
	mov bl, 0xf
	int 0x21
	dec ah
	lea si, [msg_directory_of]
	int 0x21
	inc ah
	; holds drive letter conveniently
	mov al, [msg_command]
	int 0x21
	mov al, 0xa
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

	mov al, 0xa
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
	mov al, 0xa
	int 0x21
	int 0x21

	popa ; macro
	jmp line

cat:
	dec si
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
	lea bx, [0x2000]
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

cls:
	mov ah, 0x6
	xor al, al
	mov bh, 0xf
	xor cx, cx
	mov dx, 0x184f
	int 0x10

	mov ah, 0xb
	mov dh, 24
	xor dl, dl
	int 0x21

	jmp line

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

a:
	mov al, "A"
	xor dl, dl
	jmp set_drive

b:
	mov al, "B"
	mov dl, 1
	jmp set_drive

set_drive:
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

exit:
	retf