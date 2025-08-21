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

testing db "UNREAL.SYS is testing available high memory", endl, 0

mb db "mb (", 0
kb db "kb)", endl, 0

;==============================================================================
; Main program
;==============================================================================

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

main:
    xor ah, ah
    mov bl, 0xf
    lea si, [testing]
    int 0x21

    xor cx, cx
    mov ax, 0xe801
    int 0x15
    test cx, cx
    jnz .cx_has_mem
    mov cx, ax
.cx_has_mem:
    mov [fs:0x80000], cx

    push cx
    mov ah, 0xd
    mov bl, 0xf
    shr cx, 10
    int 0x21
    xor ah, ah
    mov bl, 0xf
    lea si, [mb]
    int 0x21
    pop cx
    
    mov ah, 0xd
    mov bl, 0xf
    int 0x21
    xor ah, ah
    mov bl, 0xf
    lea si, [kb]
    int 0x21

    mov ah, 0x1
    mov al, 0xa
    mov bl, 0xf
    int 0x21

	retf