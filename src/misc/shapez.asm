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
    mov es, ax

main:
    mov ax, 0x13
    int 0x10

    mov al, 0xf
    call clear_screen

    mov al, 0x7
    mov cx, 10
    mov dx, 10
    mov bx, 300
    mov di, 180
    call draw_rect
    mov al, 0x3
    mov cx, 11
    mov dx, 11
    mov bx, 298
    mov di, 10
    call draw_rect
    mov al, 0x4
    mov cx, 300
    mov dx, 12
    mov bx, 8
    mov di, 8
    call draw_rect

    xor ah, ah
    int 0x16

quit:
    mov ax, 0x3
    int 0x10

    mov ah, 0x10
    mov bl, 0xf
    int 0x21
.no_reset:
    retf

;==============================================================================
; Graphics routines
;==============================================================================

clear_screen:
    push cx
    push di
    push es

    push ax
    mov ax, 0xa000
    mov es, ax
    pop ax

    xor di, di
    mov cx, 320*200
    cld
    rep stosb

    pop es
    pop di
    pop cx
    ret

draw_pixel:
    push ax
    push bx
    push cx
    push dx
    push edi

    mov di, ax

    mov ax, dx
    mov bx, 320
    mul bx
    add ax, cx

    xchg di, ax
    mov [fs:0xa0000+edi], al

    pop edi
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; al - color
; cx, dx - x, y
; bx, di - width, height
draw_rect:
    push bp
    mov bp, cx
    push cx
    push dx
    push bx
    push di
    add bx, cx
    add di, dx
    jmp .row
.next_row:
    cmp dx, di
    je .end
    inc dx
    mov cx, bp
.row:
    call draw_pixel
    cmp cx, bx
    je .next_row
    inc cx
    jmp .row
.end:
    pop di
    pop bx
    pop dx
    pop cx
    pop bp
    ret