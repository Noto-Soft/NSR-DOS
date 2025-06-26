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

error_not_command: db "Not a command", endl, 0
error_not_file: db "Not a file", endl, 0
error_unknown_format: db "The format of the executable is not known to the loader", endl, 0

buffer: times 128 db 0
BUFFER_END equ $
db 0

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

main:
    mov ax, cs
    mov ds, ax
    mov es, ax

line:
    lea di, [buffer]
    mov byte [di], 0
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

    push es
    mov ah, 0x4
    mov bx, 0x0
    mov es, bx
    lea di, [0x800]
    int 0x21
    pop es
    cmp al, 0
    je exec

    pop di

    cmp di, buffer
    jne not_command

    jmp line

not_command:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_command]
    int 0x21

    jmp line

dir:
    push ax
	push cx
	push dx
	push bx
	push sp
	push bp
	push si
	push di
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
    pop di
	pop si
	pop bp
	pop sp
	pop bx
	pop dx
	pop cx
	pop ax
    jmp line

type:
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

    mov ah, 0x4
    add si, 5
    mov bx, 0x0
    mov es, bx
    lea di, [0x800]
    int 0x21
    cmp ax, 0
    jne .not_exist
    mov ah, 0x3
    mov dl, [drive]
    mov bx, 0x3f00
    mov es, bx
    mov bx, 0x0
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

    pop di
	pop si
	pop bp
	pop sp
	pop bx
	pop dx
	pop cx
	pop ax
    jmp line

exec:
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

    mov ah, 0x4
    mov bx, 0x0
    mov es, bx
    lea di, [0x800]
    int 0x21
    cmp ax, 0
    jne .not_exist
    mov ah, 0x3
    mov dl, [drive]
    mov bx, 0x8000
    mov es, bx
    mov bx, 0x0
    int 0x21

    mov ax, es
    mov ds, ax

    mov ax, [es:0x0]
    cmp ax, "AD"
    jne .unknown_format
    mov al, [es:0x2]
    cmp al, 0x2
    jne .unknown_format
    push ds
    push es
    mov dl, [drive]
    mov ax, [es:0x4]
    push word cs
    push word .after
    push word es
    push ax
    retf
.after:
    pop es
    pop ds

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

    pop di
	pop si
	pop bp
	pop sp
	pop bx
	pop dx
	pop cx
	pop ax
    jmp line
.unknown_format:
    xor ah, ah
    lea si, [error_unknown_format]
    mov bl, 0x4
    int 0x21

    jmp line

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