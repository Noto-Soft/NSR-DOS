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

;==============================================================================
; Main program
;==============================================================================

start:
    mov ax, cs
    mov ds, ax
    mov ax, 0x3000
    mov es, ax

main:
    xor di, di

forever:
    xor ah, ah
    int 0x16
    cmp al, "Q" and 0x1f
    je quit
    cmp al, 0xd
    je newline
    mov [es:di], al
    inc di
    mov ah, 0x1
    mov bl, 0xf
    int 0x21
    jmp forever

newline:
    mov ah, 0x14
    int 0x21
    mov byte [es:di], 0xa
    inc di
    jmp forever

quit:
    mov ah, 0x14
    int 0x21

    xor ah, ah
    mov bl, 0xf
    xor si, si
    push ds
    mov dx, es
    mov ds, dx
    int 0x21
    pop ds

    mov ah, 0x14
    int 0x21

    retf