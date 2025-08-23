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

msg db "Address of allocated memory: ", 0
msg2 db "Type whatever and it will repeated after you press enter.", endl, 0

;==============================================================================
; Main program
;==============================================================================

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

main:
    mov cx, 600
    call testmalloc
    mov cx, 500
    call testmalloc
    mov cx, 700
    call testmalloc
    mov cx, 1000
    mov bx, 1200
    call testrealloc
    mov cx, 600
    call malloc
    call addr
    mov di, si
    mov cx, 700
    call malloc
    call addr
    call free
    mov si, di
    call free

    xor ah, ah
    mov bl, 0x7
    lea si, [msg2]
    int 0x21

    mov cx, 1
    call malloc
    test si, si
    jz exit
    xor bx, bx
    mov cx, 2
    mov byte [si], 0
.loop:
    xor ah, ah
    int 0x16
    cmp al, 0xd
    je .done
    cmp al, 0x8
    je .backspace
    mov ah, 1
    push bx
    mov bl, 0x7
    int 0x21
    pop bx
    call realloc
    test si, si
    jz exit
    mov [si+bx], al
    inc bx
    mov byte [si+bx], 0
    inc cx
    jmp .loop
.done:
    mov ah, 0x14
    int 0x21

    xor ah, ah
    int 0x21
    call free

    mov ah, 0x14
    int 0x21

    jmp exit
.backspace:
    mov ah, 0xc
    int 0x21
    cmp dl, 0
    jna .loop
    mov ah, 1
    mov al, 0x8
    push bx
    mov bl, 0x7
    int 0x21
    mov al, " "
    int 0x21
    mov al, 0x8
    int 0x21
    pop bx
    dec cx
    call realloc
    dec bx
    mov byte [si+bx], 0
    mov ah, 1
    jmp .loop

exit:
    retf

testmalloc:
    call malloc
    call addr    
    call free

    ret

testrealloc:
    call malloc
    mov byte [si], "e"
    call addr
    mov cx, bx
    call realloc
    call addr
    mov ah, 0x1
    mov al, [si]
    mov bl, 0xf
    int 0x21
    mov ah, 0x14
    int 0x21
    call free

    ret

addr:
    pusha

    push si

    xor ah, ah
    mov bl, 0x7
    lea si, [msg]
    int 0x21

    pop si

    mov ah, 0x6
    mov bl, 0x7
    mov cx, ds
    int 0x21
    mov ah, 0x1
    mov al, ":"
    int 0x21
    mov ah, 0x6
    mov cx, si
    int 0x21

    mov ah, 0x14
    int 0x21

    popa
    ret

include "src/inc/heap.inc"