bits 16

org 0x0

%define endl 0xa

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

drive: db 0

msg_command: db "# ", 0
msg_newline: db endl, 0

str_dir: db "dir", 0
str_type: db "type", 0

error_not_command_or_file: db "Not a command nor an executable file", endl, 0
error_not_file: db "File does not exist", endl, 0
error_unknown_format: db "The format of the executable is not known to the loader", endl, 0

buffer: times 96 db 0
BUFFER_END equ $
times 4 db 0 ; allow some extra space for .exe autofill
db 0
BUFFER_SPACE_END equ $

align 256

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
    cmp al, 0
    je .endofstring
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
    cmp ah, 0
    je .endofstring
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
    xor ah, ah
    mov bl, 0xf
    lea si, [msg_newline]
    int 0x21

    push di

    lea si, [buffer]

    lea di, [str_dir]
    call strcmp
    or al, al
    jz dir

    lea di, [str_type]
    call strcmp_until_di_end
    or al, al
    jz type

    pop di

    cmp di, buffer
    je line

    jmp exec

dir:
    pusha
    push ds

    xor ax, ax
    mov ds, ax
    lea di, [0x800]
    xor ah, ah
    mov bl, 0xf
.loop:
    mov al, [di]
    cmp al, 0
    je .done
    add di, 4
    mov si, di
    int 0x21
    push ds
    mov ax, cs
    mov ds, ax
    xor ah, ah
    lea si, [msg_newline]
    int 0x21
    pop ds
    dec di
    mov al, [di]
    xor ah, ah
    add di, ax
    inc di
    jmp .loop
.done:
    pop ds
    popa
    jmp line

type:
    pusha
    
    push ds
    push es

    mov ah, 0x4
    add si, 5
    xor bx, bx
    mov es, bx
    lea di, [0x800]
    int 0x21
    cmp ax, 0
    jne .not_exist
    mov ah, 0x3
    mov dl, [drive]
    mov bx, 0x4000
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

    popa
    jmp line

exec:
    pusha
    
    push ds
    push es

    mov ah, 0x4
    xor bx, bx
    mov es, bx
    lea di, [0x800]
    int 0x21
    test al, al
    jnz .check_autofill
.after_autofill_check:
    mov dl, [drive]
    mov bx, 0x2000
    mov ax, cs
    cmp bx, ax
    jne .after_error
    mov al, 1
    int 0x23
.after_error:
    mov ah, 0x3
    mov es, bx
    xor bx, bx
    int 0x21

    mov ax, es
    mov ds, ax

    mov ax, [es:0x0]
    cmp ax, "AD"
    jne .unknown_format
    mov al, [es:0x2]
    cmp al, 0x2
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
    mov ax, [es:0x4]
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
    mov bl, 0x4
    lea si, [error_not_command_or_file]
    int 0x21
.done:
    pop es
    pop ds

    popa
    jmp line
.unknown_format:
    mov ax, cs
    mov ds, ax
    xor ah, ah
    lea si, [error_unknown_format]
    mov bl, 0x4
    int 0x21

    jmp .done
.check_autofill:
    push si
.find_terminator_loop:
    inc si
    cmp byte [si-1], 0
    jne .find_terminator_loop
    mov word [si-1], ".E"
    mov word [si+1], "XE"
    pop si

    mov ah, 0x4
    xor bx, bx
    mov es, bx
    lea di, [0x800]
    int 0x21
    test al, al
    jnz .not_exist

    jmp .after_autofill_check

exit:
    retf

align 256

symbol_table:
db "start", 0
dw start
db "strcmp", 0
dw strcmp
db "strcmp_until_di_end", 0
dw strcmp_until_di_end
db "main", 0
dw main
SYMBOL_TABLE_LENGTH equ 4

times 2048-($-$$) db 0