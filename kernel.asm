bits 16

org 0x0

%define endl 0xa
%include "8086.inc"

start:
	mov ax, cs
	mov ds, ax
	mov es, ax

	mov [drive], dl

	jmp main

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

	xor ax, ax
	mov es, ax
	mov [es:cursor], dx
	mov ah, 0x2
	xor bh, bh
	int 0x10

	pop es
	pop bx
	pop ax
	ret

read_cursor:
	push ax
	push es

	xor ax, ax
	mov es, ax
	mov dx, [es:cursor]

	pop es
	pop ax
	ret

putc_attr:
	push ax
	push bx
	push cx
	push dx

	call read_cursor

	cmp al, 0xa
	je .newline
	cmp al, 0x8
	je .backspace
	cmp al, 0x9
	je .tab

	call scroll_if_need_be

	call set_char

	inc dl
	cmp dl, 80
	jb .cursor_good

	xor dl, dl
	inc dh 
	call scroll_if_need_be
.cursor_good:
	call set_cursor

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
	call set_cursor
	jmp .done
.backspace:
	dec dl
	call set_cursor
	mov al, " "
	call set_char
	jmp .done
.tab:
	add dl, 4
	and dl, ~(0b00000011)
	call set_cursor
	jmp .done
.done:
	pop dx
	pop cx
	pop bx
	pop ax
	ret

puts:
	push ax
	push bx
	push si
	mov ah, 0xe
	xor bh, bh
	cld
.loop:
	lodsb
	or al, al
	jz .done
	int 0x10
	jmp .loop
.done:
	pop si
	pop bx
	pop ax
	ret

puts_attr:
	push ax
	push dx
	push si
	cld
.loop:
	lodsb
	or al, al
	jz .done
	call putc_attr
	jmp .loop
.done:
	pop si
	pop dx
	pop ax
	ret

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
	shr al, 4
	
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

;
; Disk routines
;   - stolen from nanobytes
;

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
	shl ah, 6
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
.disk_retry: db "Retry read", endl, 0

; si - filename
; returns:
;   - di: file entry
file_get:
	push ax
	push es
	push word 0
	pop es
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
	test ax, ax
	jz .located_kernel
.skip:
	dec di
	mov al, [es:di]
	xor ah, ah
	add di, ax
	inc di
	jmp .locate_kernel_loop
.not_found:
	pop ax
	add si, 2
	mov bl, 0x3
	jmp fatal_exception
.located_kernel:
	sub di, 4
	pop es
	pop ax
	ret

; ds:si - filename
; returns:
;   - di: file entry, null if not found
file_safe_get:
	push ax
	push es
	push word 0
	pop es
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

; ds:si - filename
; returns:
;   - ax: 0 if exists
file_confirm_exists:
	push bx
	push ax
	push es
	xor ax, ax
	mov es, ax
	lea di, [0x800]
	call case_up
.locate_kernel_loop:
	mov al, [es:di]
	or al, al
	jz .not_found
	add di, 4
	call strcmp
	test ax, ax
	jz .located_kernel
	dec di
	mov al, [es:di]
	xor ah, ah
	add di, ax
	inc di
	jmp .locate_kernel_loop
.not_found:
	mov bx, 1
	jmp .done
.located_kernel:
	xor bx, bx
	jmp .done
.done:
	pop es
	pop ax
	mov ax, bx
	pop bx
	ret

; in:
;   - ds:si: filename
;   - dl: drive
;   - es:bx: buffer
file_read:
	push ax
	push cx
	push di

	push es
	xor ax, ax
	mov es, ax
	lea di, [0x800]
	call file_get

	mov ax, [es:di]
	mov cl, [es:di+2]
	pop es
	call disk_read

	pop di
	pop cx
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

floppy_error:
	mov al, 0x4
	int 0xff

drive_invalid_fs:
	mov al, 0x5
	int 0xff

disk_read_interrupt_wrapper:
	call disk_read
	iret

disk_write_interrupt_wrapper:
	call disk_write
	iret

%macro cmpje 1
	cmp ah, %1
	je .ah%1
%endmacro

%macro route 2
.ah%1:
	call %2
	jmp .done
%endmacro

%macro routel 2
.ah%1:
	push ax
	push ds
	mov ax, cs
	mov ds, ax
	cmp byte [.legacy_enabled], 1
	pop ds
	pop ax
	jne %%not_legacy
	call %2
%%not_legacy:
	jmp .done
%endmacro

int21:
	cmpje 0x0
	cmpje 0x1
	cmpje 0x2
	cmpje 0x3
	cmpje 0x4
	cmpje 0x5
	cmpje 0x6
	cmpje 0x7
	cmpje 0x8
	cmpje 0x9
	cmpje 0xa
	cmpje 0xb
	cmpje 0xc
	jmp .done
route 0x0, puts_attr
route 0x1, putc_attr
routel 0x2, file_get
routel 0x3, file_read
routel 0x4, file_confirm_exists
route 0x5, print_hex_byte
route 0x6, print_hex_word
route 0x7, file_safe_get
route 0x8, file_read_entry
route 0x9, drive_switch
route 0xa, file_soft_delete_entry
route 0xb, set_cursor
route 0xc, read_cursor
.done:
	iret
.legacy_enabled: db 1

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
	xor ah, ah
	mov al, 0x3
	int 0x10
	mov ah, 0x6
	xor al, al
	mov bh, 0x17
	xor cx, cx
	mov dx, 0x184f
	int 0x10
	mov dh, 24
	xor dl, dl
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
	call print_hex_byte
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

main:
	xor ah, ah
	mov al, 0x3
	int 0x10

	mov ah, 0x6
	xor al, al
	mov bh, 0xf
	xor cx, cx
	mov dx, 0x184f
	int 0x10

	mov dh, 24
	xor dl, dl
	call set_cursor

	lea si, [boot_txt]
	call file_safe_get
	test di, di
	jnz .boot_txt_not_null
	mov bl, 0x3
	sub sp, 2
	push cs
	call fatal_exception
.boot_txt_not_null:
	mov dl, [drive]
	mov bx, 0x4000
	mov es, bx
	xor bx, bx
	call file_read_entry

	mov ax, es
	mov ds, ax
	xor si, si
	mov bl, 0xf
	call puts_attr

	mov ax, cs
	mov ds, ax

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
	mov word [es:0xff*4], intff
	mov [es:0xff*4+2], ax
	pop es

	lea si, [command_exe]
	call file_safe_get
	test di, di
	jnz .command_exe_not_null
	mov al, 0x3
	int 0xff
.command_exe_not_null:
	mov dl, [drive]
	mov bx, 0x1000
	mov es, bx
	xor bx, bx
	call file_read_entry

	mov ax, [es:0x0]
	cmp ax, "AD"
	jne .unknown_format
	mov al, [es:0x2]
	cmp al, 0x2
	jne .unknown_format
	push ds
	push es
	mov dl, [drive]
	mov ax, [es:0x4]
	push cs
	push word .after
	push es
	push ax
	retf
.after:
	pop es
	pop ds

	jmp $

.unknown_format:
	mov al, 0x2
	int 0xff

nsr_dos: db "NSR-DOS", 0
fatal_exception_msg: db endl, endl, "A fatal exception ", 0
fatal_exception_part_2: db " has occured", endl, 0

boot_txt: db "BOOT.TXT", 0
command_exe: db "COMMAND.EXE", 0

cursor: dw 0

drive: db 0