bits 16

org 0x0

%define endl 0xa

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

msg_explainy: db "Graphix.exe - Graphics mode test", endl, "Q to quit", endl, 0
times 3 db 0 ; for some reason this memory is getting written into and i don't know why
msg_happy: db "happy", endl, 0

align 256

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov ax, 0xa000
    mov fs, ax

    jmp main

main:
    xor ah, ah
    mov al, 0x12
    int 0x10

    mov ah, 0xc
    mov cx, 160
    mov dx, 100
    mov al, 0xf
    int 0x10
    inc dx
    int 0x10
    dec dx
    add cx, 3
    int 0x10
    inc dx
    int 0x10
    add dx, 2
    inc cx
    int 0x10
    inc dx
    dec cx
    int 0x10
    dec cx
    int 0x10
    dec cx
    int 0x10
    dec cx
    int 0x10
    dec dx
    dec cx
    int 0x10

    xor ah, ah
    mov bl, 0xf
    lea si, [msg_happy]
    int 0x21

    mov ah, 0x2
    xor bh, bh
    mov dh, 28
    xor dl, dl
    int 0x10

    mov ah, 0x10
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

    retf

symbol_table:
db "start", 0
dw start
db "main", 0
dw main
SYMBOL_TABLE_LENGTH equ 2

times 512-($-$$) db 0