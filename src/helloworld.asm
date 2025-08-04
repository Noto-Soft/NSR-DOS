bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "src/inc/8086.inc"

db "AD"
db 2
db 0
dw start

msg:
	dw .end-$-2
	db "Hello, world!", endl
.end:

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov ah, 0x2
	mov bl, 0x7
	lea si, [msg]
	int 0x21

	retf