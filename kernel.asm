bits 16

org 0x0

%define endl 0xa

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    jmp main

scroll_if_need_be:
    cmp dh, 25
    jb .done
    push ax
push cx
push dx
push bx
push sp
push bp
push si
push di
    mov ah, 0x6
    mov bh, bl
    mov al, 1
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    pop di
pop si
pop bp
pop sp
pop bx
pop dx
pop cx
pop ax
    mov dh, 24
.done:
    ret

putc_attr:
    push ax
    push bx
    push cx
    push dx

    push ax
    mov ah, 0x3
    xor bh, bh
    int 0x10
    pop ax

    cmp al, 0xa
    je .newline
    cmp al, 0xd
    je .newline
    cmp al, 0x8
    je .backspace

    call scroll_if_need_be
    mov ah, 0x2
    int 0x10

    mov ah, 0x9
    mov cx, 1
    int 0x10

    inc dl
    cmp dl, 80
    jb .cursor_good

    xor dl, dl
    inc dh 
    call scroll_if_need_be
.cursor_good:
    mov ah, 0x2
    int 0x10

    push ax
push cx
push dx
push bx
push sp
push bp
push si
push di
    mov ah, 0x9
    mov al, " "
    mov cx, 1
    int 0x10
    pop di
pop si
pop bp
pop sp
pop bx
pop dx
pop cx
pop ax

    jmp .done
.newline:
    inc dh
    xor dl, dl
    call scroll_if_need_be
    mov ah, 0x2
    int 0x10
    jmp .done
.backspace:
    dec dl
    mov ah, 0x2
    int 0x10
    mov ah, 0x9
    mov al, " "
    mov cx, 1
    int 0x10
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
    push si
.loop:
    lodsb
    or al, al
    jz .done
    call putc_attr
    jmp .loop
.done:
    pop si
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

    xor dx, dx                          ; dx = 0
    mov ds, dx
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

    pop ds
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
    push ax
push cx
push dx
push bx
push sp
push bp
push si
push di                               ; save all registers, we don't know what bios modifies
    stc                                 ; set carry flag, some BIOS'es don't set it
    int 13h                             ; carry flag cleared = success
    jnc .done                           ; jump if carry not set

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
    pop ax                             ; restore registers modified
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
    int 13h
    jc floppy_error
    lea si, [.disk_retry]
    mov bl, 0x3
    call puts_attr
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

; si - filename
; di - entry sectors start
; returns:
;   - di: file entry
file_get:
    push ax
.locate_kernel_loop:
    mov al, [es:di]
    or al, al
    jz .not_found ; end of entries
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
    mov ax, cs
    mov ds, ax
    lea si, [error_file_not_found]
    mov bl, 0x4
    call puts_attr

    jmp $
.located_kernel:
    sub di, 4
    pop ax
    ret

; si - filename
; di - entry sectors start
; returns:
;   - ax: 0 if exists
file_confirm_exists:
    push bx
    push ax
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
    mov bx, 0
    jmp .done
.done:
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

floppy_error:
    mov ax, cs
    mov ds, ax
    lea si, [error_floppy]
    mov bl, 0x4
    call puts_attr
    jmp $

disk_read_interrupt_wrapper:
    call disk_read
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

int21:
    cmpje 0x0
    cmpje 0x1
    cmpje 0x2
    cmpje 0x3
    cmpje 0x4
route 0x0, puts_attr
route 0x1, putc_attr
route 0x2, file_get
route 0x3, file_read
route 0x4, file_confirm_exists
.done:
    iret

main:
    xor ah, ah
    mov al, 0x03
    int 0x10

    mov ah, 0x6
    xor al, al
    mov bh, 0x0f
    xor cx, cx
    mov dx, 0x184f
    int 0x10

    lea si, [boot_txt]
    mov dl, [drive]
    mov bx, 0x3f00
    mov es, bx
    mov bx, 0x0
    call file_read

    mov dh, 24
    xor dl, dl
    mov ah, 0x2
    int 0x10

    mov ax, es
    mov ds, ax
    lea si, [0x0]
    mov bl, 0xf
    call puts_attr

    mov ax, cs
    mov ds, ax

    mov bl, 0xf
    lea si, [msg_ivt]
    call puts_attr

    push es
    xor ax, ax
    mov es, ax
    mov ax, cs
    mov word [es:0x21*4], int21
    mov [es:0x21*4+2], ax
    mov bl, 0x3
    lea si, [msg_int21]
    call puts_attr
    mov word [es:0x22*4], disk_read_interrupt_wrapper
    mov [es:0x22*4+2], ax
    mov bl, 0x3
    lea si, [msg_int22]
    call puts_attr
    pop es

    mov bl, 0xf
    lea si, [msg_newline]
    call puts_attr

    lea si, [command_exe]
    mov dl, [drive]
    mov bx, 0x1000
    mov es, bx
    mov bx, 0x0
    call file_read

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
    lea si, [error_unknown_format]
    mov bl, 0x4
    call puts_attr

    jmp $

msg_newline: db endl, 0
msg_list: db "List of files on drive:", endl, endl, 0
msg_ivt: db "Patching IVT", endl, 0
msg_int21: db "Patched int 0x21 to IVT", endl, 0
msg_int22: db "Patched int 0x22 to IVT", endl, 0

error_floppy: db "Error reading from floppy", endl, 0
error_file_not_found: db "File not found", endl, 0
error_unknown_format: db "The format of the executable is not known to the kernel", endl, 0

boot_txt: db "BOOT.TXT", 0
command_exe: db "COMMAND.EXE", 0

drive: db 0

times 1024-($-$$) db 0