bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "src/inc/8086.inc"

db "ES"
dw start

start:
	mov ax, cs
	mov ds, ax

	xor ah, ah
	mov bl, 0xf
	lea si, [msg]
	int 0x21

	retf

msg: