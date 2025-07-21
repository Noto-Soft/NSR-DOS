bits 16

org 0h

%define endl 0ah

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

    jmp main

get_rows_from_videomode:
    cmp al, 12h
    je .rows30
    mov al, 25
    ret
.rows30:
    mov al, 30
    ret

scroll_if_need_be:
    push ax
    mov ah, 0Fh
    int 10h
    call get_rows_from_videomode
    cmp dh, al
    jb .done
    pusha
    mov ah, 6h
    mov bh, bl
    mov al, 1
    xor cx, cx
    mov dx, 184fh
    int 10h
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
    mov ah, 0Fh
    int 10h
    cmp al, 3h
    jne .graphicsMode
    pop ax

    push es

    push dx
    push di

    push ax
    mov ax, 0b800h
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
    mov ah, 9h
    xor bh, bh
    mov cx, 1
    int 10h
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
    mov ah, 3h
    xor bh, bh
    int 10h
    pop ax

    cmp al, 0ah
    je .newline
    cmp al, 8h
    je .backspace
    cmp al, 9h
    je .tab

    call scroll_if_need_be
    mov ah, 2h
    xor bh, bh
    int 10h

    call set_char

    inc dl
    cmp dl, 80
    jb .cursor_good

    xor dl, dl
    inc dh 
    call scroll_if_need_be
.cursor_good:
    mov ah, 2h
    xor bh, bh
    int 10h

    push es

    push di

    push ax
    mov ax, 0b800h
    mov es, ax
    pop ax

    call get_mem_pos

    mov al, [es:di+1]
    and al, 0f0h
    and bl, 0fh
    add bl, al
    mov [es:di+1], bl

    pop di

    pop es

    jmp .done
.newline:
    inc dh
    xor dl, dl
    call scroll_if_need_be
    mov ah, 2h
    xor bh, bh
    int 10h
    jmp .done
.backspace:
    dec dl
    mov ah, 2h
    xor bh, bh
    int 10h
    mov al, " "
    call set_char
    jmp .done
.tab:
    mov al, dl
    add al, 3
    and al, 0FCh
    mov dl, al
    mov ah, 2h
    xor bh, bh
    int 10h
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
    mov ah, 0eh
    xor bh, bh
    cld
.loop:
    lodsb
    or al, al
    jz .done
    int 10h
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
    and al, 0Fh
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
    div word [500h]                    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [502h]                    ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
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
; Reads sectors to a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to write (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to read write data
;
disk_write:
    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (number of sectors to read)
    call lba_to_chs                     ; compute CHS
    pop ax                              ; AL = number of sectors to read
    
    mov ah, 3h
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
    mov bl, 3h
    call puts_attr
    popa
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
    lea di, [800h]
    call case_up
.locate_kernel_loop:
    mov al, [es:di]
    test al, al
    jz .not_found ; end of entries
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
    mov bl, 3h
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
    lea di, [800h]
    call case_up
.locate_kernel_loop:
    mov al, [es:di]
    test al, al 
    jz .not_found ; end of entries
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
    lea di, [800h]
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
    lea di, [800h]
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
    pusha

    push es

    xor ax, ax
    mov es, ax
    mov ax, [es:di]
    mov cl, [es:di+2]
    pop es
    call disk_read

    popa
    ret

; in:
;   - dl: drive
;   - di: file entry (segment 0)
file_soft_delete_entry:
    pusha

    push es

    xor ax, ax
    mov es, ax
    
    mov byte [es:di+4], 0

    mov ax, 2
    mov cl, [es:600h+13] ; get the length of the entry sectors
    lea bx, [800h]
    call disk_write

    pop es
    call disk_read

    popa
    ret

drive_switch:
    pusha

    push es
    xor ax, ax
    mov es, ax

    push dx

    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 3Fh
    xor ch, ch
    mov [es:500h], cx
 
    inc dh
    mov [es:502h], dh
    mov byte [es:503h], 0

    mov ax, 1
    mov cl, 1
    pop dx
    push dx
    lea bx, [600h]
    int 22h

    mov al, [es:600h+2]
    test al, al
    jz drive_invalid_fs

    mov ax, 2
    mov cl, [es:600h+13]
    pop dx
    lea bx, [800h]
    int 22h

    pop es

    popa
    ret

floppy_error:
    mov al, 4h
    int 2fh

drive_invalid_fs:
    mov al, 5h
    int 2fh

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
    cmpje 0h
    cmpje 1h
    cmpje 2h
    cmpje 3h
    cmpje 4h
    cmpje 5h
    cmpje 6h
    cmpje 7h
    cmpje 8h
    cmpje 9h
    cmpje 0ah
    jmp .done
route 0h, puts_attr
route 1h, putc_attr
routel 2h, file_get
routel 3h, file_read
routel 4h, file_confirm_exists
route 5h, print_hex_byte
route 6h, print_hex_word
route 7h, file_safe_get
route 8h, file_read_entry
route 9h, drive_switch
route 0ah, file_soft_delete_entry
.done:
    iret
.legacy_enabled: db 1

int0:
    xor bl, bl
    jmp fatal_exception

int6:
    mov bl, 6h
    jmp fatal_exception

int2f:
    mov bl, al
    jmp fatal_exception

fatal_exception:
    xor ah, ah
    mov al, 3h
    int 10h
    mov ah, 6h
    xor al, al
    mov bh, 17h
    xor cx, cx
    mov dx, 184fh
    int 10h
    mov dh, 24
    xor dl, dl
    mov ah, 2h
    int 10h
    pop dx ; ip
    pop cx ; cs
    add sp, 2 ; flags
    mov ax, cs
    mov ds, ax
    mov cl, bl
    mov bl, 71h
    lea si, [nsr_dos]
    call puts_attr
    mov bl, 17h
    lea si, [fatal_exception_msg]
    call puts_attr
    call print_hex_byte
    lea si, [fatal_exception_part_2]
    call puts_attr

    mov al, 0b6h
    out 43h, al

    mov ax, 1193182 / 880
    out 42h, al
    mov al, ah
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    jmp $

main:
    xor ah, ah
    mov al, 3h
    int 10h

    mov ah, 6h
    xor al, al
    mov bh, 0fh
    xor cx, cx
    mov dx, 184fh
    int 10h

    lea si, [boot_txt]
    call file_safe_get
    test di, di
    jnz .boot_txt_not_null
    mov bl, 3h
    sub sp, 2
    push cs
    call fatal_exception
.boot_txt_not_null:
    mov dl, [drive]
    mov bx, 4000h
    mov es, bx
    xor bx, bx
    call file_read_entry

    mov dh, 24
    xor dl, dl
    mov ah, 2h
    int 10h

    mov ax, es
    mov ds, ax
    xor si, si
    mov bl, 0fh
    call puts_attr

    mov ax, cs
    mov ds, ax

    push es
    xor ax, ax
    mov es, ax
    mov ax, cs
    mov word [es:0h*4], int0
    mov [es:0h*4+2], ax
    mov word [es:6h*4], int6
    mov [es:6h*4+2], ax
    mov word [es:21h*4], int21
    mov [es:21h*4+2], ax
    mov word [es:22h*4], disk_read_interrupt_wrapper
    mov [es:22h*4+2], ax
    mov word [es:23h*4], disk_write_interrupt_wrapper
    mov [es:23h*4+2], ax
    mov word [es:2fh*4], int2f
    mov [es:2fh*4+2], ax
    pop es

    lea si, [command_exe]
    call file_safe_get
    test di, di
    jnz .command_exe_not_null
    mov al, 3h
    int 2fh
.command_exe_not_null:
    mov dl, [drive]
    mov bx, 1000h
    mov es, bx
    xor bx, bx
    call file_read_entry

    mov ax, [es:0h]
    cmp ax, "AD"
    jne .unknown_format
    mov al, [es:2h]
    cmp al, 2h
    jne .unknown_format
    push ds
    push es
    mov dl, [drive]
    mov ax, [es:4h]
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
    mov al, 2h
    int 2fh

nsr_dos: db "NSR-DOS", 0
fatal_exception_msg: db endl, endl, "A fatal exception ", 0
fatal_exception_part_2: db " has occured", endl, 0

boot_txt: db "BOOT.TXT", 0
command_exe: db "COMMAND.EXE", 0

drive: db 0