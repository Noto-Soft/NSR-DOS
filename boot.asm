bits 16

org 0x7c00

%define endl 0xd, 0xa

jmp start

; THIN header
db "R-DOS0.3 "

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

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
    shl ah, 6
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
    push ax
    push cx
    push dx
    push bx
    push sp
    push bp
    push si
    push di
    ; set carry flag, some BIOS'es don't set it
    stc
    ; carry flag cleared = success
    int 0x13
    ; jump if carry not set
    jnc .done

    ; read failed
    pop di
    pop si
    pop bp
    pop sp
    pop bx
    pop dx
    pop cx
    pop ax
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    pop di
    pop si
    pop bp
    pop sp
    pop bx
    pop dx
    pop cx
    pop ax

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
    push ax
    push cx
    push dx
    push bx
    push sp
    push bp
    push si
    push di
    xor ah, ah
    stc
    int 0x13
    jc floppy_error
    lea si, [.disk_retry]
    call puts
    pop di
    pop si
    pop bp
    pop sp
    pop bx
    pop dx
    pop cx
    pop ax
    ret
.disk_retry: db "Retry read", endl, 0

floppy_error:
    mov al, 0x4
    int 0x2f

main:
    mov ax, 1
    mov cl, 1
    mov dl, [drive]
    lea bx, [0x600]
    push 0
    pop es
    call disk_read

    mov ax, 2
    mov cl, [0x600+13]
    mov dl, [drive]
    lea bx, [0x800]
    push 0
    pop es
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
    lea bx, [0x7e00]
    push 0
    pop es
    call disk_read

    mov dl, [drive]
    jmp 0x7e0:0x0

    jmp $

msg_boot: db "Small Diversified Bootloader 1.0", endl, 0

error_kernel_not_found: db " missing", endl, 0

kernel_sys: db "KERNEL.SYS", 0

drive: db 0

times 510-($-$$) db 0
dw 0xaa55