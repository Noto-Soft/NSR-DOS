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

msg_choose_image db "Enter image filename (Or leave blank for default)", endl, 0
msg_image_doesnt_exist db "Image file requested does not exist", endl, 0

default_image db "NSRDOS.BMP", 0
image_file_name db 31 dup(0)
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

	mov ax, es
	mov ds, ax

	xor si, si
	mov ax, [si]
	cmp ax, "Bm"
	jne .check_legacy_headers
	mov al, [si+2]
	add si, 1
	cmp al, "V"
	je .gotData
	cmp al, "C"
	je .read_8bpp_pallete
	cmp al, "R"
	je .pallete4
	cmp al, "M"
	je .monochrome
	jmp .done
.check_legacy_headers:
	cmp ax, "BM"
	je .gotData
	cmp ax, "CM"
	je .read_8bpp_pallete
	cmp ax, "MM"
	je .monochrome
	cmp ax, "4M"
	jne .done
.pallete4:
	add si, 6
	mov cx, 16
	xor al, al
.pallete4_set_loop:
	mov bx, [si]
	push cx
	mov cl, [si+2]
	mov ah, 0x12
	int 0x21
	pop cx
	inc al
	add si, 3
	loop .pallete4_set_loop
	call draw_fullscreen_4bpp_bmp
	jmp .finally_done
.monochrome:
	add si, 6
	mov ah, 0x12
	mov al, 0x0
	mov bx, [si]
	mov cl, [si+2]
	int 0x21
	add si, 3
	mov al, 0x1
	mov bx, [si]
	mov cl, [si+2]
	int 0x21
	add si, 3
	call draw_fullscreen_mono_bmp
	jmp .finally_done
.read_8bpp_pallete:
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
.finally_done:
	mov ax, cs
	mov ds, ax

	xor ah, ah
	int 0x16
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

;==============================================================================
; VGA routines
;==============================================================================

clear_screen:
    push ax
    push cx
    push di
    push es

    mov ax, 0xa000
    mov es, ax

    xor al, al

    xor di, di
    mov cx, 320*200
	cld
    rep stosb

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

;
; NSBMP routines
;

; ds:si - bitmap data
draw_fullscreen_bmp:
	push ax
	push bx
	push cx

	xor ebx, ebx
	mov cx, 320*200
.loop:
	mov al, [si+bx]
	mov [fs:0xa0000+ebx], al
	inc bx
	cmp bx, cx
	jb .loop

	pop cx
	pop bx
	pop ax
	ret

; ds:si - bitmap data
draw_fullscreen_4bpp_bmp:
	push ax
	push bx
	push cx
	push ebp

	xor bx, bx
	xor ebp, ebp
	mov cx, 320*(200/2)
.loop:
	mov al, [si+bx]
	push ax
	shr al, 4
	mov [fs:0xa0000+ebp], al
	pop ax
	and al, 0xf
	inc bp
	mov [fs:0xa0000+ebp], al
	inc bx
	inc ebp
	cmp bx, cx
	jb .loop

	pop ebp
	pop cx
	pop bx
	pop ax
	ret	

; ds:si - bitmap data
draw_fullscreen_mono_bmp:
	push ax
	push bx
	push cx
	push ebp

	xor bx, bx
	xor ebp, ebp
	mov cx, 320*(200/8)
.loop:
	mov al, [si+bx]
rept 8 {
	push ax
	rol al, 1
	and al, 0x1
	mov [fs:0xa0000+ebp], al
	pop ax
	shl al, 1
	inc ebp
}
	inc bx
	cmp bx, cx
	jb .loop

	pop ebp
	pop cx
	pop bx
	pop ax
	ret	