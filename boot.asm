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
    mov ah, 08h
    int 13h
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

    xor dx, dx                          ; dx = 0
    div word [0x500]                    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [0x502]                    ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
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

    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax                             ; restore registers modified
    ret


;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    xor ah, ah
    stc
    int 13h
    jc floppy_error
    lea si, [.disk_retry]
    call puts
    popa
    ret
.disk_retry: db "Retry read", endl, 0

floppy_error:
    mov al, 0x4
    int 0x23

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
    jz .not_found ; end of entries
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