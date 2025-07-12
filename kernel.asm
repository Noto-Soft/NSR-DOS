bits 16

org 0x0

%define endl 0xa

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    jmp main

get_rows_from_videomode:
    cmp al, 0x12
    je .rows30
    mov al, 25
    ret
.rows30:
    mov al, 30
    ret

scroll_if_need_be:
    push ax
    mov ah, 0x0F
    int 0x10
    call get_rows_from_videomode
    cmp dh, al
    jb .done
    pusha
    mov ah, 0x6
    mov bh, bl
    mov al, 1
    xor cx, cx
    mov dx, 0x184f
    int 0x10
    popa
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
    push ax
    mov ah, 0x0F
    int 0x10
    cmp al, 0x3
    jne .graphicsMode
    pop ax

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
.graphicsMode:
    pop ax
    push ax
    push bx
    push cx
    mov ah, 0x9
    xor bh, bh
    mov cx, 1
    int 0x10
    pop cx
    pop bx
    pop ax
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
    cmp al, 0x8
    je .backspace

    call scroll_if_need_be
    mov ah, 0x2
    xor bh, bh
    int 0x10

    call set_char

    inc dl
    cmp dl, 80
    jb .cursor_good

    xor dl, dl
    inc dh 
    call scroll_if_need_be
.cursor_good:
    mov ah, 0x2
    xor bh, bh
    int 0x10

    push es

    push di

    push ax
    mov ax, 0xb800
    mov es, ax
    pop ax

    call get_mem_pos

    mov al, [es:di+1]
    and al, 0xf0
    and bl, 0x0f
    add bl, al
    mov [es:di+1], bl

    pop di

    pop es

    jmp .done
.newline:
    inc dh
    xor dl, dl
    call scroll_if_need_be
    mov ah, 0x2
    xor bh, bh
    int 0x10
    jmp .done
.backspace:
    dec dl
    mov ah, 0x2
    xor bh, bh
    int 0x10
    mov al, " "
    call set_char
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
    and al, 0x0F
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
    mov bl, 0x3
    call puts_attr
    popa
    ret
.disk_retry: db "Retry read", endl, 0

; si - filename
; di - entry sectors start
; returns:
;   - di: file entry
file_get:
    push ax
    call case_up
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
    cmpje 0x5
    cmpje 0x6
    jmp .done
route 0x0, puts_attr
route 0x1, putc_attr
route 0x2, file_get
route 0x3, file_read
route 0x4, file_confirm_exists
route 0x5, print_hex_byte
route 0x6, print_hex_word
.done:
    iret

int0:
    xor bl, bl
    jmp fatal_exception

int6:
    mov bl, 0x6
    jmp fatal_exception

int23:
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
    mov ah, 0x2
    int 0x10
    pop dx ; ip
    pop cx ; cs
    add sp, 2 ; flags
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
    call print_hex_word
    mov al, ":"
    call putc_attr
    mov cx, dx
    call print_hex_word
    mov al, 0xa
    call putc_attr

    mov al, 0b10110110
    out 0x43, al

    mov ax, 1193182 / 880
    out 0x42, al
    mov al, ah
    out 0x42, al

    in al, 0x61
    or al, 3
    out 0x61, al

    popa
    push cx
    push bx
    mov cx, ax
    mov bl, 0x17
    call print_hex_word
    mov al, " "
    call putc_attr
    pop cx
    call print_hex_word
    mov al, " "
    call putc_attr
    pop cx
    call print_hex_word
    mov al, " "
    call putc_attr
    mov cx, dx
    call print_hex_word
    mov al, " "
    call putc_attr
    mov cx, si
    call print_hex_word
    mov al, " "
    call putc_attr
    mov cx, di
    call print_hex_word
    mov al, 0xa
    call putc_attr
    mov cx, ds
    call print_hex_word
    mov al, " "
    call putc_attr
    mov cx, es
    call print_hex_word

    jmp $

main:
    xor ah, ah
    mov al, 0x3
    int 0x10

    mov ah, 0x6
    xor al, al
    mov bh, 0x0f
    xor cx, cx
    mov dx, 0x184f
    int 0x10

    lea si, [boot_txt]
    mov dl, [drive]
    mov bx, 0x4000
    mov es, bx
    xor bx, bx
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
    mov word [es:0x23*4], int23
    mov [es:0x23*4+2], ax
    pop es

    lea si, [command_exe]
    mov dl, [drive]
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
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
    pusha
    mov al, 0x2
    int 0x23

error_floppy: db "Error reading from floppy", endl, 0
error_file_not_found: db "File not found", endl, 0

msg_newline: db endl, 0

nsr_dos: db "NSR-DOS", 0
fatal_exception_msg: db endl, endl, "A fatal exception ", 0
fatal_exception_part_2: db " has occured at ", 0

boot_txt: db "BOOT.TXT", 0
command_exe: db "COMMAND.EXE", 0

drive: db 0

times 1536-($-$$) db 0