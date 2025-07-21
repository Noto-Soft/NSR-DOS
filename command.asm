bits 16

org 0h

%define endl 0ah

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

drive: db 0

msg_directory_of: db "Directory of drive ", 0
msg_command: db "A>", 0
msg_sectors_used: db endl, "Sectors used: ", 0
msg_sectors_free: db endl, "Sectors free: ", 0
msg_sectors_total: db endl, "Total sectors: ", 0

str_commands: db "List of commands:", endl, 0
str_a: db "a:", 0
    db " - Set drive to drive A: (drive #0)", endl, 0
str_b: db "b:", 0
    db " - Set drive to drive B: (drive #1)", endl, 0
str_cls: db "cls", 0
    db " - Clear console output", endl, 0
str_del: db "del", 0
    db " - Deletes a file from the disk directory", endl, 0
str_dir: db "dir", 0
    db " - List files on the disk directory", endl, 0
str_help: db "help", 0
    db " - List available commands and their functions", endl, 0
str_type: db "type", 0
    db " - Read a file out to the console", endl, 0
db 0

error_not_command_or_file: db "Not a command nor an executable file", endl, 0
error_not_file: db "File does not exist", endl, 0
error_drive_missing: db "Disk is not inserted into the drive", endl, 0

buffer: times 96 db 0
BUFFER_END equ $
times 4 db 0 ; allow some extra space for .exe autofill
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
    mov bl, 0fh
    lea si, [msg_command]
    int 21h
.loop:
    xor ah, ah
    int 16h
    cmp al, 0dh
    je line_done
    cmp al, 8h
    je .backspace
    cmp di, BUFFER_END
    jnb .loop
    mov ah, 1h
    mov bl, 0fh
    int 21h
    mov [di], al
    inc di
    mov byte [di], 0
    jmp .loop
.backspace:
    cmp di, buffer
    jna .loop
    mov ah, 1h
    mov bl, 0fh
    int 21h
    dec di
    mov byte [di], 0
    jmp .loop

line_done:
    mov ah, 1h
    mov bl, 0fh
    mov al, 0ah
    int 21h

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
    pusha
    push ds

    xor ah, ah
    inc ah
    mov al, 0ah
    mov bl, 0fh
    int 21h
    dec ah
    lea si, [msg_directory_of]
    int 21h
    inc ah
    mov al, [msg_command] ; holds drive letter conveniently
    int 21h
    mov al, 0ah
    int 21h
    int 21h

    xor ax, ax
    mov ds, ax
    lea di, [800h]
    xor ah, ah
    mov bl, 0fh
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
    int 21h
    mov ah, 1h
    mov al, " "
    int 21h
    mov ah, 5h
    mov cl, [di-2]
    int 21h
    add dx, cx
    mov ah, 1h
    mov al, 0ah
    int 21h
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
    mov bl, 0fh
    lea si, [msg_sectors_used]
    int 21h

    mov ah, 6h
    mov cx, dx
    int 21h

    mov ah, 1h
    mov al, 0ah
    int 21h
    int 21h

    popa
    jmp line

type:
    pusha
    
    push ds
    push es

    add si, 5
    mov ah, 7h
    int 21h
    test di, di
    jz .not_exist
    mov ah, 8h
    mov dl, [drive]
    lea bx, [4000h]
    mov es, bx
    xor bx, bx
    int 21h

    mov ax, es
    mov ds, ax

    xor ah, ah
    mov bl, 0fh
    lea si, [0h]
    int 21h

    jmp .done
.not_exist:
    mov ax, cs
    mov ds, ax
    
    xor ah, ah
    mov bl, 4h
    lea si, [error_not_file]
    int 21h
.done:
    pop es
    pop ds

    popa
    jmp line

exec:
    pusha
    
    push ds
    push es

    mov ah, 7h
    int 21h
    test di, di
    jz .check_autofill
.after_autofill_check:
    mov dl, [drive]
    lea bx, [2000h]
    mov ax, cs
    cmp bx, ax
    jne .after_error
    mov al, 1
    int 2fh
.after_error:
    mov ah, 8h
    mov es, bx
    xor bx, bx
    int 21h

    mov ax, es
    mov ds, ax

    mov ax, [es:0h]
    cmp ax, "AD"
    jne .unknown_format
    mov al, [es:2h]
    cmp al, 2h
    jne .unknown_format
    push ax
    push cx
    push dx
    push bx
    push sp
    push bp
    push si
    push di
    push ds
    push es
    push fs
    mov dl, [drive]
    mov ax, [es:4h]
    push word cs
    push word .after
    push word es
    push ax
    retf
.after:
    pop fs
    pop es
    pop ds
    pop di
    pop si
    pop bp
    pop sp
    pop bx
    pop dx
    pop cx
    pop ax

    jmp .done
.not_exist:
    mov ax, cs
    mov ds, ax
    
    xor ah, ah
    mov bl, 4h
    lea si, [error_not_command_or_file]
    int 21h
.done:
    pop es
    pop ds

    popa
    jmp line
.unknown_format:
    mov al, 2h
    int 2fh
.check_autofill:
    push si
.find_terminator_loop:
    inc si
    cmp byte [si-1], 0
    jne .find_terminator_loop
    mov word [si-1], ".E"
    mov word [si+1], "XE"
    pop si

    mov ah, 7h
    int 21h
    test di, di
    jz .not_exist

    jmp .after_autofill_check

help:
    xor ah, ah
    mov bl, 0fh
    lea si, [str_commands]
    int 21h
.find_next_string:
    mov al, [si]
    inc si
    test al, al
    jnz .find_next_string
    mov al, [si]
    test al, al
    jz line
    int 21h
    jmp .find_next_string

cls:
    mov ah, 6h
    xor al, al
    mov bh, 0fh
    xor cx, cx
    mov dx, 184fh
    int 10h

    mov dh, 24
    xor dl, dl
    mov ah, 2h
    int 10h

    jmp line

del:
    pusha

    mov ah, 7h
    add si, 4
    mov dl, [drive]
    int 21h
    mov ah, 0ah
    int 21h

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
    pusha
    push es
    mov ah, 8h
    int 13h
    jc drive_empty
    pop es
    popa
    mov byte [drive], dl
    mov byte [msg_command], al
    mov ah, 9h
    int 21h
    jmp dir

drive_empty:
    xor ah, ah
    mov bl, 4h
    lea si, [error_drive_missing]
    int 21h
    jmp line

drive_invalid_fs:
    mov al, 5h
    int 2fh

floppy_error:
    mov al, 4h
    int 2fh

exit:
    retf

symbol_table:
db "start", 0
dw start
SYMBOL_TABLE_LENGTH equ 1