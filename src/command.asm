bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "src/inc/8086.inc"

db "ES"
dw start

drive db 0

msg_directory_of db "Directory of drive ", 0
msg_command db "A>", 0
msg_sectors_used db endl, "Kilobytes used: ", 0
msg_insert_diskette db endl, "Insert a diskette into drive ", 0
msg_insert_diskette2 db ", then press any key", endl, 0

str_commands db endl, "List of commands:", endl, 0
str_a db "a:", 0
	db " - Set drive to drive A: (drive #0)", endl, 0
str_b db "b:", 0
	db " - Set drive to drive B: (drive #1)", endl, 0
str_cls db "cls", 0
	db " - Clear console output", endl, 0
str_del db "del", 0
	db " - Deletes a file from the disk directory", endl, 0
str_dir db "dir", 0
	db " - List files on the disk directory", endl, 0
str_help db "help", 0
	db ", "
str_cmds db "cmds", 0
	db " - List available commands and their functions", endl, 0
str_type db "type", 0
	db " - Read a file out to the console", endl, 0
db endl, 0
db 0

str_start db "start", 0

error_not_command_or_file db "Not a command nor an executable file", endl, 0
error_not_file db "File does not exist", endl, 0
error_drive_missing db "Disk is not inserted into the drive", endl, 0

buffer times 148 db 0
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

	lea di, [str_type]
	mov bl, " "
	call strcmp_until_delimiter
	or al, al
	jz type

	lea di, [str_del]
	mov bl, " "
	call strcmp_until_delimiter
	or al, al
	jz del

	lea di, [str_help]
	call strcmp
	or al, al
	jz help
	lea di, [str_cmds]
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

%include "src/command/cls.asm"
%include "src/command/del.asm"
%include "src/command/dir.asm"
%include "src/command/drive_stuff.asm"
%include "src/command/exec.asm"
%include "src/command/help.asm"
%include "src/command/type.asm"

exit:
	retf