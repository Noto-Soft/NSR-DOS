;==============================================================================
; fasm directives
;==============================================================================

use16
org 0x0

endl equ 0xa
include "src/inc/8086.inc"

;==============================================================================
; Executable header
;==============================================================================

db "ES"
dw start
db 20 dup(0)

;==============================================================================
; Constants and variables
;==============================================================================

msg_sig db "Bootloader's signature: "
msg_sig_len = $-msg_sig

msg_unknown db "Bootloader has invalid signature. Want to repair the bootloader? [Y/n]"
msg_unknown_len = $-msg_unknown

msg_not db endl, "Bootloader was not repaired.", endl
msg_not_len = $-msg_not

msg_was db endl, "Bootloader was successfully repaired.", endl
msg_was_len = $-msg_was

str_valid_sig db "R-DOS0.9 "

;==============================================================================
; Main program
;==============================================================================

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

main:
    mov ax, 0
    mov cl, 1
    mov dl, 0
    lea bx, [bootloader]
    int 0x22

    mov ah, 0x3
    mov bl, 0x7
	mov cx, msg_sig_len
	lea si, [msg_sig]
	int 0x21
	mov cx, 9
	lea si, [bootloader+2]
	int 0x21
    mov ah, 0x1
    mov al, 0xa
    int 0x21
	
	lea si, [bootloader+2]
	lea di, [str_valid_sig]
	mov cx, 9
	cld
	repe cmpsb
	jz .valid

	mov ah, 0x3
	mov bl, 0x4
	mov cx, msg_unknown_len
	lea si, [msg_unknown]
	int 0x21
	xor ah, ah
	int 0x16
	cmp al, "n"
	je .skip
	cmp al, "N"
	je .skip
	mov ax, 0
	mov cl, 1
	mov dl, 0
	lea bx, [valid_bootloader]
	int 0x23

	mov ah, 0x3
	mov bl, 0x2
	mov cx, msg_was_len
	lea si, [msg_was]
	int 0x21

	retf
.skip:
	mov ah, 0x3
	mov bl, 0x4
	mov cx, msg_not_len
	lea si, [msg_not]
	int 0x21
.valid:
	retf

bootloader db 512 dup(0)

valid_bootloader: