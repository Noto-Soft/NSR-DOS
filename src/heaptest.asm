bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "src/inc/8086.inc"

db "AD"
db 2
db 0
dw start

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    jmp main

; cx - size in bytes
; returns: si - pointeer
malloc:
    push ax
    push bx
    lea si, [heap]
    jmp .loop
.nextloop:
    mov bx, [si+1]
    add si, bx
    add si, HEAP_BLOCK_HEADER_SIZE
.loop:
    cmp si, HEAP_TOP
    jae .fate
    mov al, [si]
    test al, al
    jnz .nextloop
    mov bx, [si+1]
    test bx, bx
    jz .uninitialized
    cmp cx, bx
    ja .nextloop
    mov cx, bx ; for safety, use the whole block
.uninitialized:
    mov byte [si], 1
    mov [si+1], cx
.done:
    add si, HEAP_BLOCK_HEADER_SIZE
    pop bx
    pop ax
    ret
.fate:
    xor si, si
    pop bx
    pop ax
    ret

; si - pointer to data to free
; if invalid pointer then it just silently fails and sets al to 1
free:
    push si
    cmp si, heap + HEAP_BLOCK_HEADER_SIZE
    jb .fail
    cmp si, HEAP_TOP
    ja .fail
    sub si, HEAP_BLOCK_HEADER_SIZE
    mov byte [si], 0
.done:
    pop si
    ret
.fail:
    mov al, 1
    pop si
    ret

main:
    mov cx, 600
    call tests
    mov cx, 500
    call tests
    mov cx, 700
    call tests

end:
    retf

tests:
    xor ah, ah
    mov bl, 0x7
    lea si, [msg]
    int 0x21

    call malloc

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

    call free

    mov ah, 0x1
    mov al, endl
    mov bh, 0x7
    int 0x21

    ret

msg db "Address of allocated memory: ", 0

heap resb 0x2000
HEAP_TOP equ $
HEAP_BLOCK_HEADER_SIZE equ 3