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

helpmsg:
    db "ECHO [/C <FORMATTING BYTE>] [/H] [/K] [/N] <text>", endl
    db "--------------------------------------------------------------------------------"
    db "/C <FORMATTING BYTE> - sets the formatting of the output (2 digit hex byte)", endl
    db "/H - when toggled on, prints the help message you're seeing now", endl
    db "/K - when toggled on, wait for a keypress after the output", endl
    db "/N - when toggled on, the output is not followed by a newline", endl
    db 0

;==============================================================================
; Main program
;==============================================================================

start:
    mov bl, 0x7
    mov dl, 0
    inc si

loopidy:
    mov al, [si]
    cmp al, "/"
    je special
    cmp al, " "
    jne .c1
    inc si
    jmp loopidy
.c1:
    jmp main

special:
    inc si
    mov al, [si]
    cmp al, "C"
    je color
    cmp al, "N"
    je nonewline
    cmp al, "K"
    je waitforkeypress
    cmp al, "H"
    je help
    jmp main

color:
    inc si
    mov al, [si]
    cmp al, " "
    jne .c1
    inc si
.c1:
    call hex2byte
    add si, 2
    mov bl, al

    jmp loopidy

nonewline:
    or dl, 1b
    inc si
    jmp loopidy

waitforkeypress:
    or dl, 10b
    inc si
    jmp loopidy

main:
    xor ah, ah
    int 0x21

    test dl, 1b
    jnz .c1
    mov ah, 0x14
    int 0x21
.c1:
    test dl, 10b
    jz .c2
    xor ah, ah
    int 0x16
.c2:
    retf

help:
    mov ax, cs
    mov ds, ax

    xor ah, ah
    mov bl, 0xf
    lea si, [helpmsg]
    int 0x21

    retf

hex2byte:
    push si
    push bx
    xor bx, bx
    lodsb
    call .hex_nibble
    jc .error
    shl al, 4
    mov bl, al
    lodsb
    call .hex_nibble
    jc .error
    or bl, al
    mov al, bl
    pop bx
    pop si
    ret
.error:
    xor al, al
    pop bx
    pop si
    ret
.hex_nibble:
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .check_lower
    cmp al, 'F'
    jbe .upper
    jmp .check_lower
.check_lower:
    cmp al, 'a'
    jb .bad
    cmp al, 'f'
    ja .bad
    sub al, 'a' - 10
    clc
    ret
.digit:
    sub al, '0'
    clc
    ret
.upper:
    sub al, 'A' - 10
    clc
    ret
.bad:
    stc
    ret