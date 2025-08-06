bits 16
cpu 8086
org 0x0

%define endl 0xa
%include "src/inc/8086.inc"

db "ES"
dw start
times 20 db 0

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
    push si
    add si, HEAP_BLOCK_HEADER_SIZE
    add si, cx
    cmp si, HEAP_TOP
    jae .fate2
    pop si
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
.fate2:
    pop si
.fate:
    xor si, si
    pop bx
    pop ax
    ret

; zero out the allocated memory
; same as malloc  just zeros out so no garbage
zalloc:
    call malloc
    push cx
    push si
.loop:
    mov byte [si], 0
    inc si
    loop .loop
    pop si
    pop cx
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

; si - pointer to original memory
; cx - new size
; returns: si - new memory
realloc:
    push ax
    push bx
    push cx
    push di
    mov bx, [si-HEAP_BLOCK_HEADER_SIZE+1]
    mov ax, cx
    cmp cx, bx
    jnb .larger
    mov ax, bx
.larger:
    mov di, si
    call zalloc
    xchg si, di
    mov cx, ax
    push di
    rep movsb
    pop di
    mov si, di
    pop di
    pop cx
    pop bx
    pop ax
    ret

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

end:
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
    mov al, 0xa
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

    mov ah, 0x1
    mov al, endl
    mov bl, 0x7
    int 0x21

    popa
    ret


msg db "Address of allocated memory: ", 0

heap resb 0x2000
HEAP_TOP equ $
HEAP_BLOCK_HEADER_SIZE equ 3