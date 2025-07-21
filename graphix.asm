bits 16

org 0h

%define endl 0ah

db "AD"
db 2
db 1
dw start
dw symbol_table
dw SYMBOL_TABLE_LENGTH

drive: db 0

msg_choose_image: db "Enter image filename (Or leave blank for default)", endl, "When finished viewing the beauty you desire, press q", endl, 0
msg_image_doesnt_exist: db "Image file requested does not exist", endl, 0

default_image: db "NSRDOS.BMP", 0
image_file_name: times 64 db 0
FILENAME_BUFFER_LENGTH equ $-image_file_name
db 0

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
    mov ax, 0a000h
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

    mov ax, 0a000h
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
    mov ax, 0a000h
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

; al - pallete to get
; returns:
;   bl, bh, cl: rgb
get_pallete:
    push ax
    push dx
    mov dx, 3C7h
    out dx, al

    mov dx, 3C9h
    in  al, dx
    mov bl, al
    in  al, dx
    mov bh, al
    in  al, dx
    mov cl, al
    pop dx
    pop ax
    ret

; al - pallete to set
; bl, bh, cl: rgb
set_pallete:
    push ax
    push dx
    mov dx, 3C8h
    out dx, al

    inc dx
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al
    mov al, cl
    out dx, al
    pop dx
    pop ax
    ret

main:
    xor ah, ah
    mov bl, 3h
    lea si, [msg_choose_image]
    int 21h

    lea di, [image_file_name]
    xor bx, bx
    mov byte [di], 0
.get_filename_loop:
    xor ah, ah
    int 16h
    cmp al, 0dh
    je .got_filename
    cmp al, 8h
    je .backspace
    cmp bx, FILENAME_BUFFER_LENGTH
    jnb .get_filename_loop
    mov ah, 1h
    push bx
    mov bl, 0fh
    int 21h
    pop bx
    mov [di+bx], al
    inc bx
    mov byte [di+bx], 0
    jmp .get_filename_loop
.backspace:
    cmp bx, 0
    jna .get_filename_loop
    mov ah, 1h
    push bx
    mov al, 8h
    mov bl, 0fh
    int 21h
    pop bx
    mov byte [di+bx], 0
    dec bx
    jmp .get_filename_loop
.got_filename:
    xor ah, ah
    mov al, 13h
    int 10h

    mov al, 1h
    call clear_screen
    
    mov al, 3
    call get_pallete
    xor al, al
    call set_pallete

    lea si, [image_file_name]
    cmp byte [si], 0
    jne .continue

    lea si, [default_image]
.continue:
    mov ah, 7h
    int 21h
    test di, di
    jz .not_exist
    mov ah, 8h
    mov dl, [drive]
    mov bx, 3000h
    mov es, bx
    xor bx, bx
    int 21h

    mov al, 0fh
    mov dx, 50
    mov cx, 50
    call draw_pixel

    mov ax, es
    mov ds, ax

    xor si, si
    cmp word [si], "BM"
    je .gotData
    cmp word [si], "CM"
    jne .done
    add si, 6
    mov cx, 256
    xor al, al
.pallete_set_loop:
    mov bx, [si]
    push cx
    mov cl, [si+2]
    call set_pallete
    pop cx
    inc al
    add si, 3
    loop .pallete_set_loop
    sub si, 6
.gotData:
    add si, 6
    call draw_fullscreen_bmp

    mov ax, cs
    mov ds, ax
.wait:
    xor ah, ah
    int 16h
    cmp al, "q"
    je .done
    cmp al, "Q"
    je .done
    jmp .wait
.done:
    xor ah, ah
    mov al, 3h
    int 10h
    
    mov dh, 24
    xor dl, dl
    mov ah, 2h
    int 10h

    retf
.not_exist:
    xor ah, ah
    mov al, 3h
    int 10h

    mov dh, 24
    xor dl, dl
    mov ah, 2h
    int 10h

    mov ax, cs
    mov ds, ax

    xor ah, ah
    mov bl, 4h
    lea si, [msg_image_doesnt_exist]
    int 21h

    retf

symbol_table:
db "start", 0
dw start
db "draw_pixel", 0
dw draw_pixel
db "draw_fullscreen_bmp", 0
dw draw_fullscreen_bmp
db "set_pallete", 0
dw set_pallete
db "get_pallete", 0
dw get_pallete
db "main", 0
dw main
SYMBOL_TABLE_LENGTH equ 6