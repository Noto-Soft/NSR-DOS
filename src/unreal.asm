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

testing db "UNREAL.SYS is testing available high memory (up to 14mb)", endl, 0
msg db "Unreal mode is working perfectly!", endl, 0

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
    mov dx, bx
.cx_has_mem:
    sub cx, 1024 ; dont count the isa memory hole

    mov [fs:0x80000], cx
    mov [fs:0x80002], dx

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

    xor ebx, ebx
    mov bx, cx
    shl ebx, 10
    add ebx, 0x10000
    sub ebx, 2

    mov dword [fs:ebx], 69420
    mov eax, [fs:ebx]
    cmp eax, 69420
    jne quit
    xor ah, ah
    mov bl, 0xa
    lea si, [msg]
    int 0x21

quit:
    mov ah, 0x1
    mov al, 0xa
    mov bl, 0xf
    int 0x21

	retf