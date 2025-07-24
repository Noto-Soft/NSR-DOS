bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "8086.inc"

db "AD"
db 2
db 0
dw start

msg: db "Hello world!", endl, 0

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	xor ah, ah
	mov bl, 0x7
	lea si, [msg]
	int 0x21

	retf