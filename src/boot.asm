use16
org 0x7c00

endl equ 0xd, 0xa
include "src/inc/8086.inc"

jmp start

; THIN header
db "R-DOS0.9 "

start:
	xor ax, ax
	mov ds, ax
	mov es, ax

	mov ax, 0x9000
	mov ss, ax
	mov sp, 0x0

	; just in case the pc speaker is still enabled from a reboot or something
	in al, 0x61
	and al, not 3
	out 0x61, al

	lea si, [msg_boot]
	call puts

	mov [drive], dl

	push es
	mov ah, 0x08
	int 0x13
	jc floppy_error
	pop es

	and cl, 0x3F
	xor ch, ch
	mov [0x500], cx
 
	inc dh
	mov [0x502], dh
	mov byte [0x503], 0

	jmp 0x0000:main

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

strcmp:
	push si
	push di
.loop:
	mov al, [si]
	mov ah, [di]
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

	; dx = 0
	xor dx, dx
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
	call puts
	popa ; macro
	ret
.disk_retry db "Retry read", endl, 0

floppy_error:
	mov al, 4
	int 0xff

main:
	mov ax, 1
	mov cl, 1
	mov dl, [drive]
	xor bx, bx
	mov es, bx
	lea bx, [0x600]
	call disk_read

	mov ax, 2
	mov cl, [0x600+13]
	mov dl, [drive]
	xor bx, bx
	mov es, bx
	lea bx, [0x800]
	call disk_read

	lea si, [kernel_sys]
	lea di, [0x800]
.locate_kernel_loop:
	mov al, [di]
	or al, al
	; end of entries
	jz .not_found
	add di, 4
	call strcmp
	test ax, ax
	jz .located_kernel
	dec di
	mov al, [di]
	xor ah, ah
	add di, ax
	inc di
	jmp .locate_kernel_loop
.not_found:
	lea ax, [puts]
	lea si, [kernel_sys]
	call ax
	lea si, [error_kernel_not_found]
	call ax

	jmp $
.located_kernel:
	sub di, 4

	mov ax, [di]
	mov cl, [di+2]
	mov dl, [drive]
	lea bx, [0x7000]
	mov es, bx
	xor bx, bx
	call disk_read

	mov ax, [es:0x0]
	cmp ax, "ES"
	jne $
	mov ax, [es:0x2]
	mov dl, [drive]
	push es
	push ax
	retf

msg_boot db "Small Diversified Bootloader 1.0", endl, 0

error_kernel_not_found db " missing", endl, 0

kernel_sys db "KERNEL.SYS", 0

drive db ?

db 510-($-$$) dup(0)
dw 0xaa55