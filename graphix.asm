bits 16

org 0x0

%define endl 0xa

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

msg_explainy: db "Graphix.exe - Graphics mode test", endl, "Q to quit", 0
msg_happy: db "happy", endl, 0

align 256

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    jmp main

clear_screen:
    push ax
    push cx
    push di
    push es
    mov ax, 0xa000
    mov es, ax
    xor di, di
    mov cx, 320*200
.loop:
    mov [es:di], al
    inc di
    loop .loop
    pop es
    pop di
    pop cx
    pop ax
    ret

draw_pixel:
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov di, ax

    mov ax, 0xa000
    mov es, ax

    mov ax, dx
    mov bx, 320
    mul bx
    add ax, cx

    xchg di, ax
    mov [es:di], al

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

main:
    xor ah, ah
    mov al, 0x13
    int 0x10

    mov al, 0x1
    call clear_screen
    
    mov cx, 160
    mov dx, 100
    mov al, 0xf
    call draw_pixel
    inc dx
    call draw_pixel
    dec dx
    add cx, 3
    call draw_pixel
    inc dx
    call draw_pixel
    add dx, 2
    inc cx
    call draw_pixel
    inc dx
    dec cx
    call draw_pixel
    dec cx
    call draw_pixel
    dec cx
    call draw_pixel
    dec cx
    call draw_pixel
    dec dx
    dec cx
    call draw_pixel

    xor ah, ah
    mov bl, 0xf0
    lea si, [msg_happy]
    int 0x21

    mov ah, 0x2
    xor bh, bh
    mov dh, 23
    xor dl, dl
    int 0x10

    xor ah, ah
    mov bl, 0xf
    lea si, [msg_explainy]
    int 0x21
.wait:
    xor ah, ah
    int 0x16
    cmp al, "q"
    je .done
    cmp al, "Q"
    je .done
    jmp .wait
.done:
    xor ah, ah
    mov al, 0x3
    int 0x10
    
    mov dh, 24
    xor dl, dl
    mov ah, 0x2
    int 0x10

    retf

symbol_table:
db "start", 0
dw start
db "main", 0
dw main
SYMBOL_TABLE_LENGTH equ 2

times 512-($-$$) db 0