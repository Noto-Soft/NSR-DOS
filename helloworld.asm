bits 16

org 0h

%define endl 0ah

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

msg: db "Hello world!", endl, 0

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    xor ah, ah
    mov bl, 7h
    lea si, [msg]
    int 21h

    retf

symbol_table:
db "start", 0
dw start
SYMBOL_TABLE_LENGTH equ 2