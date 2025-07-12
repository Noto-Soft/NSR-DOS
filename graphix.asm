bits 16

org 0x0

%define endl 0xa

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

drive: db 0
nsrdos_bmp: db "NSRDOS.BMP", 0

align 256

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    jmp main

clear_screen:
    push ax
    push cx
    push di
    push es
    push ax
    mov ax, 0xa000
    mov es, ax
    pop ax
    xor di, di
    mov cx, 320*200
.loop:
    mov [es:di], al
    inc di
    loop .loop
    pop es
    pop di
    pop cx
    pop ax
    ret

draw_pixel:
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov di, ax

    mov ax, 0xa000
    mov es, ax

    mov ax, dx
    mov bx, 320
    mul bx
    add ax, cx

    xchg di, ax
    mov [es:di], al

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ds:si - bitmap data
draw_fullscreen_bmp:
    push ax
    push bx
    push cx
    push es
    mov ax, 0xa000
    mov es, ax

    xor bx, bx
    mov cx, 320*200
.loop:
    mov al, [si+bx]
    mov [es:bx], al
    inc bx
    cmp bx, cx
    jb .loop

    pop es
    pop cx
    pop bx
    pop ax
    ret

main:
    xor ah, ah
    mov al, 0x13
    int 0x10

    mov al, 0x1
    call clear_screen
    
    mov ah, 0x3
    mov dl, [drive]
    lea si, [nsrdos_bmp]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    int 0x21

    mov al, 0xf
    mov dx, 50
    mov cx, 50
    call draw_pixel

    mov ax, es
    mov ds, ax

    xor si, si
    cmp word [si], "BM"
    jne .done
    add si, 6
    call draw_fullscreen_bmp
.wait:
    xor ah, ah
    int 0x16
    cmp al, "q"
    je .done
    cmp al, "Q"
    je .done
    jmp .wait
.done:
    xor ah, ah
    mov al, 0x3
    int 0x10
    
    mov dh, 24
    xor dl, dl
    mov ah, 0x2
    int 0x10

    retf

symbol_table:
db "start", 0
dw start
db "draw_pixel", 0
dw draw_pixel
db "draw_fullscreen_bmp", 0
dw draw_fullscreen_bmp
db "main", 0
dw main
SYMBOL_TABLE_LENGTH equ 4

times 512-($-$$) db 0