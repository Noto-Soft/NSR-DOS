;==============================================================================
; fasm directives
;==============================================================================

use16
org 0x0

endl equ 0xa
include "src/inc/8086.inc"
include "src/inc/center.inc"

;==============================================================================
; Executable header
;==============================================================================

db "ES"
dw start
db 20 dup(0)

;==============================================================================
; Constants and variables
;==============================================================================

title: center_text "NSR-DOS Shell 0.61"
instructon: center_text "Up and down arrows to select; Enter to run executable; Q/q to quit; a/b: drives"

msg_insert_diskette db endl, "Insert a diskette into drive ", 0
msg_insert_diskette2 db ", then press any key", endl, 0
msg_any_key db endl, "Press any key...", 0

error_unknown_format db "The file was not a valid executable.", endl, 0
error_reading db "Error reading from floppy", endl, 0
error_drive_missing db "Disk is not inserted into the drive", endl, 0

sp_save dw ?
selected dw ?
selected_file_type db ?
counter dw ?
amount dw ?
drive db ?
lazy dw ?
before_drive db ?
largest_text db ?
largest_size db ?
last_dot dw ?
last_cx dw ?

title_color db 0x06
instruction_color db 0x07
entry_color db 0x0e
selected_color db 0x1e
bg_color db 0x00

;==============================================================================
; Main program
;==============================================================================

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov [drive], dl
	mov [before_drive], dl
	mov [sp_save], sp

main:
	mov ah, 0x1
	mov ch, 0x3f
	int 0x10

	call set_gold_if_available
	mov word [selected], 1

	call render_directories
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
	cmp al, "a"
	je .a
	cmp al, "b"
	je .b
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
.a:
	xor dl, dl
	cmp [drive], dl
	je .loop
	mov al, "A"
	jmp set_drive
.b:
	mov dl, 1
	cmp [drive], dl
	je .loop
	mov al, "B"
	jmp set_drive
.quit:
	mov ah, 0x9
	mov dl, [before_drive]
	int 0x21

	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	retf

set_drive:
	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	mov byte [largest_text], 0
	mov byte [largest_size], 0

	xor ah, ah
	mov bl, 0xf
	lea si, [msg_insert_diskette]
	int 0x21
	inc ah
	int 0x21
	dec ah
	lea si, [msg_insert_diskette2]
	int 0x21
	push ax
	xor ah, ah
	int 0x16
	pop ax
	pusha ; macro
	push es
	mov ah, 0x8
	int 0x13
	jc crash_drive_empty
	pop es
	popa ; macro
	mov [drive], dl
	mov ah, 0x9
	int 0x21

	jmp main

set_gold_if_available:
	push ax
	push bx
	push cx

	mov byte [title_color], 0xe
	mov ah, 0xf
	int 0x21
	test al, al
	jz .dont_set_pallete

	mov ah, 0x12
	mov al, 0x14
	mov bl, 63
	mov bh, 50
	mov cl, 0
	int 0x21
	mov byte [title_color], 0x6
.dont_set_pallete:
	pop cx
	pop bx
	pop ax
	ret

crash_drive_empty:
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
	lea si, [error_drive_missing]
	int 0x21
	
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
	cmp byte [selected_file_type], 1
	je .continue
	cmp byte [selected_file_type], 2
	je read_file
	jmp main.loop
.continue:
	pusha
	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	call clear_free

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

	call set_gold_if_available

	xor ah, ah
	mov bl, [title_color]
	lea si, [msg_any_key]
	int 0x21

	xor ah, ah
	int 0x16

	popa
	jmp main

read_file:
	pusha
	mov ah, 0x10
	mov bl, 0xf
	int 0x21

	mov ah, 0x1
	mov cx, 0x0607
	int 0x10

	call clear_free

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

	push ds
	mov ax, es
	mov ds, ax
	xor ah, ah
	mov bl, 0x7
	xor si, si
	int 0x21
	pop ds

	pop es

	xor ah, ah
	mov bl, [title_color]
	lea si, [msg_any_key]
	int 0x21

	xor ah, ah
	int 0x16

	popa
	jmp main

;==============================================================================
; Filesystem routines
;==============================================================================

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
; Misc routines
;==============================================================================

find_last_dot:
	push es
	push ax
	push si
	mov ax, cs
	mov es, ax
	cld
.loop:
	lodsb
	test al, al
	jz .done
	cmp al, "."
	jne .loop
	mov [es:last_dot], si
	jmp .loop
.done:
	pop si
	mov cx, [es:last_dot]
	sub cx, si
	mov si, [es:last_dot]
	pop ax
	pop es
	ret

clear_free:
	push ax
	push bx
	push cx
	push di
	push es
	mov bx, 0x3000
.loop:
	mov es, bx
	xor di, di
	xor ax, ax
	mov cx, 8
	cld
	rep stosw

	inc bx
	cmp bx, 0x6000
	jne .loop
.done:
	pop es
	pop di
	pop cx
	pop bx
	pop ax
	ret

;==============================================================================
; Rendering routines
;==============================================================================

render_blank:
	push ax
	push bx

	mov ah, 0x10
	mov bl, [bg_color]
	int 0x21

	pop bx
	pop ax
	ret

render_head:
	pusha

	mov ah, 0x3
	mov bl, [title_color]
	mov cx, 80
	lea si, [title]
	int 0x21
	mov bl, [instruction_color]
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

	mov bl, [entry_color]

	push ax
	mov ax, [counter]
	cmp ax, [selected]
	jne .not_selected
	mov bl, [selected_color]
.not_selected:
	pop ax

	mov [lazy], di
	push ds
	push ax
	mov ax, es
	mov ds, ax
	pop ax
	push ax
	push cx
	mov ah, 0x3
	mov si, di
	push si
	call find_last_dot
	pop si
	dec cx
	int 0x21
	pop cx
	pop ax
	pop ds
	mov ah, 0x1
	mov al, " "
	mov bl, [entry_color]
	int 0x21
	mov ah, 0xc
	int 0x21
	cmp dl, [largest_text]
	jna .not_larger
	mov [largest_text], dl
	jmp .after_not_larger
.not_larger:
	mov dl, [largest_text]
	mov ah, 0xb
	int 0x21
.after_not_larger:
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
	mov al, " "
	int 0x21

	mov ah, 0xc
	int 0x21
	cmp dl, [largest_size]
	jna .not_larger_size
	mov [largest_size], dl
	jmp .after_not_larger_size
.not_larger_size:
	mov dl, [largest_size]
	mov ah, 0xb
	int 0x21
.after_not_larger_size:	
	mov si, [lazy]
	push ds
	push ax
	mov ax, es
	mov ds, ax
	pop ax
	push cx
	call find_last_dot
	pop cx
	xor ah, ah
	int 0x21
	pop ds
	push ax
	mov ax, [selected]
	cmp word [counter], ax
	jne .le_skip
	mov byte [selected_file_type], 0
	cmp word [es:si], "EX"
	jne .check_txt
	cmp word [es:si+2], "E"
	jne .check_txt
	mov byte [selected_file_type], 1
	jmp .le_skip
.check_txt:
	cmp word [es:si], "TX"
	jne .le_skip
	cmp word [es:si+2], "T"
	jne .le_skip
	mov byte [selected_file_type], 2
.le_skip:
	pop ax
	inc ah
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