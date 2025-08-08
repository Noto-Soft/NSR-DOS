;==============================================================================
; fasm directives
;==============================================================================

use16
org 0x0

endl equ 0xa
include "src/inc/8086.inc"
include "src/inc/write_mode.inc"

;==============================================================================
; Executable header
;==============================================================================

db "ES"
dw start
times 20 db 0

;==============================================================================
; Constants and variables
;==============================================================================

nsr_dos db "NSR-DOS", 0
fatal_exception_msg db endl, endl, "A fatal exception ", 0
fatal_exception_part_2 db " has occured", endl, 0

command_exe db "COMMAND.EXE", 0

cursor dw 0

drive db 0

next_appendation dw l_end

;==============================================================================
; Main program
;==============================================================================

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov [drive], dl

main:
	mov ax, 0x3
	int 0x10

	mov ah, 0x6
	xor al, al
	mov bh, 0xf
	xor cx, cx
	mov dx, 0x184f
	int 0x10

	xor dx, dx
	call set_cursor

	call init_serial

	push es
	xor ax, ax
	mov es, ax
	mov ax, cs
	mov word [es:0x0*4], int0
	mov [es:0x0*4+2], ax
	mov word [es:0x6*4], int6
	mov [es:0x6*4+2], ax
	mov word [es:0x21*4], int21
	mov [es:0x21*4+2], ax
	mov word [es:0x22*4], disk_read_interrupt_wrapper
	mov [es:0x22*4+2], ax
	mov word [es:0x23*4], disk_write_interrupt_wrapper
	mov [es:0x23*4+2], ax
	mov word [es:0x24*4], int24
	mov [es:0x24*4+2], ax
	mov word [es:0xff*4], intff
	mov [es:0xff*4+2], ax
	pop es

	mov bl, 0xf
	mov si, [next_appendation]
	call putsfz_attr
	call putsfz_attr
	mov [next_appendation], si

	lea si, [command_exe]
	call file_safe_get
	test di, di
	jnz .command_exe_not_null
	mov al, 3
	int 0xff
.command_exe_not_null:
	mov dl, [drive]
	mov bx, 0x1000
	mov es, bx
	xor bx, bx
	call file_read_entry

	mov ax, [es:0x0]
	cmp ax, "ES"
	mov ax, [es:0x2]
	push ds
	push es
	mov dl, [drive]
	lea bx, [.command_exe_return]
	push cs
	push bx
	push es
	push ax
	retf
.command_exe_return:
	pop es
	pop ds

	jmp $
.unknown_format:
	mov al, 2
	int 0xff

;==============================================================================
; Video routines
;==============================================================================

scroll_if_need_be:
	push ax
	mov al, 25
	cmp dh, al
	jb .done
	pusha ; macro
	mov ah, 0x6
	mov bh, bl
	mov al, 1
	xor cx, cx
	mov dx, 0x184f
	int 0x10
	popa ; macro
	mov dh, al
	dec dh
.done:
	pop ax
	ret

get_mem_pos:
	push ax
	push dx
	xor ax, ax
	mov al, dh
	mov ah, 80
	mul ah
	xor dh, dh
	add ax, dx
	mov di, ax
	pop dx
	pop ax
	shl di, 1
	ret

set_char:
	push es

	push dx
	push di

	push ax
	mov ax, 0xb800
	mov es, ax
	pop ax

	call get_mem_pos

	mov [es:di], al
	mov [es:di+1], bl

	pop di
	pop dx

	pop es
	ret

set_cursor:
	push ax
	push bx
	push es

	mov ax, cs
	mov es, ax
	mov [es:cursor], dx
	mov ah, 0x2
	xor bh, bh
	int 0x10

	pop es
	pop bx
	pop ax
	ret

set_cursor_mem:
	push ax
	push es

	mov ax, cs
	mov es, ax
	mov [es:cursor], dx

	pop es
	pop ax
	ret

update_cursor:
	push ax
	push bx
	push dx
	push es

	mov ax, cs
	mov es, ax
	mov dx, [es:cursor]
	mov ah, 0x2
	xor bh, bh
	int 0x10

	pop es
	pop dx
	pop bx
	pop ax
	ret

read_cursor:
	push ax
	push es

	mov ax, cs
	mov es, ax
	mov dx, [es:cursor]

	pop es
	pop ax
	ret

write_character_memory:
	push ax
	push bx
	push cx
	push dx

	call read_cursor

	cmp al, endl
	je .newline
	cmp al, 0x8
	je .backspace

	call scroll_if_need_be

	call set_char

	inc dl
	cmp dl, 80
	jb .cursor_good

	xor dl, dl
	inc dh 
	call scroll_if_need_be
.cursor_good:
	push es

	push di

	push ax
	mov ax, 0xb800
	mov es, ax
	pop ax

	call get_mem_pos

	mov al, [es:di+1]
	and al, 0xf0
	and bl, 0xf
	add bl, al
	mov [es:di+1], bl

	pop di

	pop es

	jmp .done
.newline:
	inc dh
	xor dl, dl
	call scroll_if_need_be
	jmp .done
.backspace:
	dec dl
	mov al, " "
	call set_char
	jmp .done
.done:
	call set_cursor_mem
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;==============================================================================
; Serial routines
;==============================================================================

init_serial:
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al

    mov dx, 0x3F8
    mov al, 0x03
    out dx, al
    mov dx, 0x3F9
    mov al, 0x00
    out dx, al

    mov dx, 0x3FB
    mov al, 0x03
    out dx, al

    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al

    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al

    ret

write_character_serial_help:
	push dx
	push ax
.wait:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jz .wait

    mov dx, 0x3F8
    pop ax
    out dx, al
	pop dx
    ret

write_character_serial:
	cmp al, 0x8
	je .backspace
	call write_character_serial_help
	ret
.backspace:
	call write_character_serial_help
	mov al, " "
	call write_character_serial_help
	mov al, 0x8
	call write_character_serial_help
	ret

;==============================================================================
; Unified Output API
;==============================================================================

set_mode:
	push es
	push ax
	mov ax, cs
	mov es, ax
	pop ax
	mov [es:write_character.write_mode], al
	pop es
	ret

write_character:
	push dx
	push ax
	push es
	mov ax, cs
	mov es, ax
	mov dl, [es:.write_mode]
	pop es
	pop ax
	cmp dl, MODE_SERIAL
	jne .cga
	call write_character_serial
	jmp .done
.cga:
	call write_character_memory
.done:
	pop dx
	ret
.write_mode db 0

putc_attr:
	call write_character
	call update_cursor
	ret

puts_attr:
	push ax
	push si
	cld
.loop:
	lodsb
	or al, al
	jz .done
	call write_character
	jmp .loop
.done:
	pop si
	pop ax
	call update_cursor
	ret

putsfz_attr:
	push ax
	cld
.loop:
	lodsb
	or al, al
	jz .done
	call write_character
	jmp .loop
.done:
	pop ax
	call update_cursor
	ret

putsle_attr:
	push ax
	push cx
	push si
	cld
	mov cx, [si-2]
.loop:
	lodsb
	call putc_attr
	loop .loop
	pop si
	pop cx
	pop ax
	ret

putsls_attr:
	push ax
	push cx
	push si
	cld
	; cx specified pre-call
.loop:
	lodsb
	call putc_attr
	loop .loop
	pop si
	pop cx
	pop ax
	ret

print_hex_digit:
	push bx
	cmp al, 10
	jl .number
	add al, 'A' - 10
	jmp .print
.number:
	add al, '0'
.print:
	pop bx
	call putc_attr
	ret

; al- byte
; bl - format
print_hex_byte:
	push ax
	push cx

	mov al, cl
	push cx
	mov cl, 4
	shr al, cl
	pop cx
	
	call print_hex_digit

	mov al, cl
	and al, 0xF
	call print_hex_digit

	pop cx
	pop ax
	ret

print_hex_word:
	xchg ch, cl
	call print_hex_byte
	xchg ch, cl
	call print_hex_byte
	ret

print_decimal_cx:
    push ax
    push bx
    push dx
    push si

    xor si, si

    cmp cx, 0
    jne .convert

    mov al, '0'
    call putc_attr
    jmp .done
.convert:
    mov ax, cx
.next_digit:
    xor dx, dx
	push bx
    mov bx, 10
    div bx
	pop bx
    push dx
    inc si
    cmp ax, 0
    jne .next_digit
.print_digits:
    pop dx
    add dl, '0'
    mov al, dl
    call putc_attr
    dec si
    jnz .print_digits
.done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

;==============================================================================
; String routines
;==============================================================================

; si
; di
strcmp:
	push si
	push di
.loop:
	mov al, [si]
	mov ah, [es:di]
	inc si
	inc di
	cmp al, ah
	jne .notequal
	cmp al, 0
	je .endofstring
	jmp .loop
.endofstring:
	xor ax, ax
	jmp .done
.notequal:
	mov ax, 1
	jmp .done
.done:
	pop di
	pop si
	ret

case_up:
	push ax
	push si
	cld
.loop:
	lodsb

	test al, al
	jz .print
	cmp al, 'a'
	jb .loop
	cmp al, 'z'
	ja .loop

	sub al, 'a' - 'A'
	mov [si-1], al
	
	jmp .loop
.print:
	pop si
	pop ax
	ret

find_zero:
	push ax
.loop:
	lodsb
	test al, al
	jnz .loop
	pop ax
	ret

;==============================================================================
; Disk routines
;   - stolen from nanobytes
;==============================================================================

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:
	push ax
	push dx
	push ds

	; dx = 0
	xor dx, dx
	mov ds, dx
	; ax = LBA / SectorsPerTrack
	div word [0x500]
										; dx = LBA % SectorsPerTrack

	; dx = (LBA % SectorsPerTrack + 1) = sector
	inc dx
	; cx = sector
	mov cx, dx

	; dx = 0
	xor dx, dx
	; ax = (LBA / SectorsPerTrack) / Heads = cylinder
	div word [0x502]
										; dx = (LBA / SectorsPerTrack) % Heads = head
	; dh = head
	mov dh, dl
	; ch = cylinder (lower 8 bits)
	mov ch, al
	push cx
	mov cl, 6
	shl ah, cl
	pop cx
	; put upper 2 bits of cylinder in CL
	or cl, ah

	pop ds
	pop ax
	; restore DL
	mov dl, al
	pop ax
	ret

;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:
	; save registers we will modify
	push ax
	push bx
	push cx
	push dx
	push di

	; temporarily save CL (number of sectors to read)
	push cx
	; compute CHS
	call lba_to_chs
	; AL = number of sectors to read
	pop ax
	
	mov ah, 0x02
	; retry count
	mov di, 3
.retry:
	; save all registers, we don't know what bios modifies
	pusha ; macro
	; set carry flag, some BIOS'es don't set it
	stc
	; carry flag cleared = success
	int 0x13
	; jump if carry not set
	jnc .done

	; read failed
	popa ; macro
	call disk_reset

	dec di
	test di, di
	jnz .retry
.fail:
	; all attempts are exhausted
	jmp floppy_error
.done:
	popa ; macro

	pop di
	pop dx
	pop cx
	pop bx
	; restore registers modified
	pop ax
	ret

;
; Reads sectors to a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to write (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to read write data
;
disk_write:
	; save registers we will modify
	push ax
	push bx
	push cx
	push dx
	push di

	; temporarily save CL (number of sectors to read)
	push cx
	; compute CHS
	call lba_to_chs
	; AL = number of sectors to read
	pop ax
	
	mov ah, 0x3
	; retry count
	mov di, 3
.retry:
	; save all registers, we don't know what bios modifies
	pusha ; macro
	; set carry flag, some BIOS'es don't set it
	stc
	; carry flag cleared = success
	int 0x13
	; jump if carry not set
	jnc .done

	; read failed
	popa ; macro
	call disk_reset

	dec di
	test di, di
	jnz .retry
.fail:
	; all attempts are exhausted
	jmp floppy_error
.done:
	popa ; macro

	pop di
	pop dx
	pop cx
	pop bx
	; restore registers modified
	pop ax
	ret

;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
	pusha ; macro
	xor ah, ah
	stc
	int 0x13
	jc floppy_error
	lea si, [.disk_retry]
	mov bl, 0x3
	call puts_attr
	popa ; macro
	ret
.disk_retry db "Retry read", endl, 0

;==============================================================================
; ThinFS Routines
;==============================================================================

; ds:si - filename
; returns:
;   - di: file entry, null if not found
file_safe_get:
	push ax
	push es
	xor ax, ax
	mov es, ax
	lea di, [0x800]
	call case_up
.locate_kernel_loop:
	mov al, [es:di]
	test al, al 
	; end of entries
	jz .not_found
	add di, 4
	mov al, [es:di]
	test al, al
	jz .skip
	call strcmp
	test al, al
	jz .located_kernel
.skip:
	dec di
	mov al, [es:di]
	xor ah, ah
	add di, ax
	inc di
	jmp .locate_kernel_loop
.not_found:
	xor di, di
	pop es
	pop ax
	ret
.located_kernel:
	sub di, 4
	pop es
	pop ax
	ret

; in:
;   - dl: drive
;   - es:bx: buffer
;   - di: file entry (segment 0)
file_read_entry:
	pusha ; macro

	push es

	xor ax, ax
	mov es, ax
	mov ax, [es:di]
	mov cl, [es:di+2]
	pop es
	call disk_read

	popa ; macro
	ret

; in:
;   - dl: drive
;   - di: file entry (segment 0)
file_soft_delete_entry:
	pusha ; macro

	push es

	xor ax, ax
	mov es, ax
	
	mov byte [es:di+4], 0

	mov ax, 2
	; get the length of the entry sectors
	mov cl, [es:0x600+13]
	lea bx, [0x800]
	call disk_write

	pop es
	call disk_read

	popa ; macro
	ret

drive_switch:
	pusha ; macro

	push es
	xor ax, ax
	mov es, ax

	push dx

	push es
	mov ah, 0x08
	int 0x13
	jc floppy_error
	pop es

	and cl, 0x3F
	xor ch, ch
	mov [es:0x500], cx
 
	inc dh
	mov [es:0x502], dh
	mov byte [es:0x503], 0

	mov ax, 1
	mov cl, 1
	pop dx
	push dx
	lea bx, [0x600]
	call disk_read

	mov al, [es:0x600+2]
	test al, al
	jz drive_invalid_fs

	mov ax, 2
	mov cl, [es:0x600+13]
	pop dx
	lea bx, [0x800]
	call disk_read

	pop es

	popa ; macro
	ret

;==============================================================================
; Memory routines
;==============================================================================

clear_free:
	push ax
	push bx
	push cx
	push di
	push es
	mov bx, 0x2000
.loop:
	mov es, bx
	xor di, di
	xor ax, ax
	mov cx, 8
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
; Interrupt handlers/wrappers
;==============================================================================

disk_read_interrupt_wrapper:
	call disk_read
	iret

disk_write_interrupt_wrapper:
	call disk_write
	iret

macro route index, handler {
    cmp ah, index
    jne @f
    call handler
    jmp .done
@@:
}

int21:
	route 0x0, puts_attr
	route 0x1, putc_attr
	route 0x2, putsle_attr
	route 0x3, putsls_attr
	route 0x4, putsfz_attr
	route 0x5, print_hex_byte
	route 0x6, print_hex_word
	route 0x7, file_safe_get
	route 0x8, file_read_entry
	route 0x9, drive_switch
	route 0xa, file_soft_delete_entry
	route 0xb, set_cursor
	route 0xc, read_cursor
	route 0xd, print_decimal_cx
	route 0xe, set_mode
.done:
	iret

int24:
	route 0x0, clear_free
.done:
	iret

int0:
	xor bl, bl
	jmp fatal_exception

int6:
	mov bl, 0x6
	jmp fatal_exception

intff:
	mov bl, al
	jmp fatal_exception

fatal_exception:
	cmp bl, 0x6
	jna .continue
	mov bl, 0xff
.continue:
	xor ah, ah
	mov al, 0x3
	int 0x10
	mov ah, 0x6
	xor al, al
	mov bh, 0x17
	xor cx, cx
	mov dx, 0x184f
	int 0x10
	xor dx, dx
	call set_cursor
	; ip
	pop dx
	; cs
	pop cx
	; flags
	add sp, 2
	mov ax, cs
	mov ds, ax
	mov cl, bl
	mov bl, 0x71
	lea si, [nsr_dos]
	call puts_attr
	mov bl, 0x17
	lea si, [fatal_exception_msg]
	call puts_attr
	xor ch, ch
	call print_decimal_cx
	lea si, [fatal_exception_part_2]
	call puts_attr

	mov al, 0xb6
	out 0x43, al

	mov ax, 1193182 / 880
	out 0x42, al
	mov al, ah
	out 0x42, al

	in al, 0x61
	or al, 3
	out 0x61, al

	jmp $

;==============================================================================
; Errors
;==============================================================================

floppy_error:
	mov al, 4
	int 0xff

drive_invalid_fs:
	mov al, 5
	int 0xff

l_end: