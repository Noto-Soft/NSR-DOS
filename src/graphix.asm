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

db "(c) 2025 Notosoft Solutions", 0

;==============================================================================
; Constants and variables
;==============================================================================

pre_stack dw 0

drive db ?

err_vga_not_installed db "You must have a VGA card installed.", endl, 0

msg_choose_image db "Enter image filename (Or leave blank for default)", endl, "When finished viewing the beauty you desire, press q", endl, 0
msg_image_doesnt_exist db "Image file requested does not exist", endl, 0

default_image db "NSRDOS.BMP", 0
image_file_name db 128 dup(0)
FILENAME_BUFFER_LENGTH = $-image_file_name
db 0

;==============================================================================
; Main program
;==============================================================================

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov [drive], dl
	mov [pre_stack], sp

main:
	mov ah, 0xf
	int 0x21
	test al, al
	jnz .prompt_filename
	xor ah, ah
	mov bl, 0x4
	lea si, [err_vga_not_installed]
	int 0x21
	jmp .cancel
.prompt_filename:
	xor ah, ah
	mov bl, 0x3
	lea si, [msg_choose_image]
	int 0x21

	lea di, [image_file_name]
	xor bx, bx
	mov byte [di], 0
.get_filename_loop:
	xor ah, ah
	int 0x16
	cmp al, 0xd
	je .got_filename
	cmp al, 0x8
	je .backspace
	cmp bx, FILENAME_BUFFER_LENGTH
	jnb .get_filename_loop
	mov ah, 0x1
	push bx
	mov bl, 0xf
	int 0x21
	pop bx
	mov [di+bx], al
	inc bx
	mov byte [di+bx], 0
	jmp .get_filename_loop
.backspace:
	cmp bx, 0
	jna .get_filename_loop
	mov ah, 0x1
	push bx
	mov al, 0x8
	mov bl, 0xf
	int 0x21
	pop bx
	mov byte [di+bx], 0
	dec bx
	jmp .get_filename_loop
.got_filename:
	xor ah, ah
	mov al, 0x13
	int 0x10

	mov al, 0x1
	call clear_screen

	lea si, [image_file_name]
	cmp byte [si], 0
	jne .continue

	lea si, [default_image]
.continue:
	mov ah, 0x7
	int 0x21
	test di, di
	jz .not_exist
	mov ah, 0x8
	mov dl, [drive]
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
	mov ah, 0x12
	int 0x21
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

	mov ah, 0xb
	xor dx, dx
	int 0x21

	mov sp, [pre_stack]
	retf
.not_exist:
	xor ah, ah
	mov al, 0x3
	int 0x10

	mov ah, 0xb
	xor dx, dx
	int 0x21

	mov ax, cs
	mov ds, ax

	xor ah, ah
	mov bl, 0x4
	lea si, [msg_image_doesnt_exist]
	int 0x21
.cancel:
	mov sp, [pre_stack]
	retf

;
; VGA routines
;

clear_screen:
    push ax
    push cx
    push di
    push es

    ; Set ES to video memory segment A000h
    mov ax, 0xa000
    mov es, ax

    ; Set AL to the value to clear the screen with (e.g., 0 for black)
    xor al, al        ; Clear AL (set to 0)

    ; Clear screen buffer
    xor di, di        ; Start at offset 0
    mov cx, 320*200   ; Number of pixels (bytes in mode 13h)
	cld
    rep stosb         ; Store AL to ES:DI, CX times

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

;
; NSBMP routines
;

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