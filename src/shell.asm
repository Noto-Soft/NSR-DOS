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

macro center_text str {
    local len, pad, left_pad, right_pad
    virtual at 0
        db str
        len = $
    end virtual
    pad = 80 - len
    left_pad = pad / 2
    right_pad = pad - left_pad
    repeat left_pad
        db ' '
    end repeat
    db str
    repeat right_pad
        db ' '
    end repeat
}

title:
    center_text "NSR-DOS Shell v0.0"

instructon:
	center_text "Up and down arrows to select; Enter to run executable; Q/q to quit"

error_unknown_format db "The file was not a valid executable.", endl, 0
error_reading db "Error reading from floppy", endl, 0

sp_save dw ?
selected dw ?
counter dw ?
amount dw ?
drive db ?
lazy dw ?

;==============================================================================
; Main program
;==============================================================================

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov [drive], dl
	mov [sp_save], sp

main:
	mov ah, 0x1
	mov ch, 0x3f
	int 0x10

	mov word [selected], 1

	call render_blank
	call render_head
.loop:
	call render_directories
	xor ah, ah
	int 0x16
	cmp al, "q"
	je .quit
	cmp al, "Q"
	je .quit
	cmp ah, 0x48
	je .up
	cmp ah, 0x50
	je .down
	cmp al, 0xd
	je run_file
	jmp .loop
.up:
	mov ax, [selected]
	dec ax
	cmp ax, 0
	jne .up_dont_wrap_around
	mov ax, [amount]
.up_dont_wrap_around:
	mov [selected], ax
	jmp .loop
.down:
	mov ax, [selected]
	cmp ax, [amount]
	jne .down_dont_wrap_around
	xor ax, ax
.down_dont_wrap_around:
	inc ax
	mov [selected], ax
	jmp .loop
.quit:
	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	retf

crash_unknown_format:
	mov ax, cs
	mov ds, ax

	mov sp, [sp_save]

	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	xor ah, ah
	mov bl, 0x4
	lea si, [error_unknown_format]
	int 0x21

	retf

crash_floppy_error:
	mov ax, cs
	mov ds, ax

	mov sp, [sp_save]

	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	xor ah, ah
	mov bl, 0x4
	lea si, [error_reading]
	int 0x21

	retf

;==============================================================================
; The scary
;==============================================================================

run_file:
	pusha
	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	push es

	push ds
	call filename_from_number
	mov ah, 0x7
	int 0x21
	pop ds
	test di, di
	jz crash_floppy_error
	mov ah, 0x8
	mov dl, [drive]
	lea bx, [0x5000]
	mov es, bx
	xor bx, bx
	int 0x21

	mov ax, [es:0x0]
	cmp ax, "ES"
	jne crash_unknown_format
	mov ax, [es:0x2]
	push ds
	push es
	mov dl, [drive]
	lea bx, [.after]
	push cs
	push bx
	push es
	push ax
	retf
.after:
	pop es
	pop ds

	pop es

	popa
	jmp main


;
; Filesystem routines
;

filename_from_number:
	pusha

	xor ax, ax
	mov ds, ax
	lea di, [0x800]
	xor ah, ah
	xor cx, cx
	xor dx, dx
	mov word [es:counter], 0
.loop:
	inc word [es:counter]

	xor si, si
	mov al, [di]
	cmp al, 0
	je .done
	add di, 4
	mov al, [di]
	cmp al, 0
	je .skip

	mov ax, [es:counter]
	cmp ax, [es:selected]
	je .found
.skip:
	dec di
	mov al, [di]
	xor ah, ah
	add di, ax
	inc di
	jmp .loop
.found:
	mov si, di
.done:
	mov [es:lazy], si
	popa
	mov si, [es:lazy]
	ret

;==============================================================================
; Rendering routines
;==============================================================================

render_blank:
	push ax
	push bx

	mov ah, 0x10
	mov bl, 0xf0
	int 0x21

	pop bx
	pop ax
	ret

render_head:
	pusha

	mov ah, 0x3
	mov bl, 0x1f
	mov cx, 80
	lea si, [title]
	int 0x21
	mov bl, 0x17
	lea si, [instructon]
	int 0x21

	popa
	ret

render_directories:
	pusha

	mov ah, 0xb
	mov dx, 0x0200
	int 0x21

	push es

	xor ax, ax
	mov es, ax
	lea di, [0x800]
	xor ah, ah
	xor cx, cx
	xor dx, dx
	mov word [counter], 0
.loop:
	inc word [counter]

	mov al, [es:di]
	cmp al, 0
	je .done
	add di, 4
	mov al, [es:di]
	cmp al, 0
	je .skip

	mov bl, 0xf0

	push ax
	mov ax, [counter]
	cmp ax, [selected]
	jne .not_selected
	mov bl, 0xa0
.not_selected:
	pop ax

	push ds
	push ax
	mov ax, es
	mov ds, ax
	pop ax
	mov si, di
	int 0x21
	pop ds
	mov ah, 0x1
	mov al, " "
	int 0x21

	mov ah, 0xd
	mov cl, [es:di-2]
	push cx
	add cl, 1
	shr cl, 1
	int 0x21
	pop cx
	add dx, cx

	mov ah, 0x1
	mov al, "k"
	int 0x21
	mov al, "b"
	int 0x21

	mov al, endl
	int 0x21
.skip:
	dec di
	mov al, [es:di]
	xor ah, ah
	add di, ax
	inc di
	jmp .loop
.done:
	pop es

	mov ax, [counter]
	dec ax
	mov [amount], ax

	popa
	ret