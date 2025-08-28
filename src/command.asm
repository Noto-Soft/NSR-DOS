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
db 20 dup(0)

;==============================================================================
; Constants and variables
;==============================================================================

drive db ?

msg_directory_of db "Directory of drive ", 0
msg_command db "A:\>", 0
msg_sectors_used db endl, "Kilobytes used: ", 0
msg_insert_diskette db endl, "Insert a diskette into drive ", 0
msg_insert_diskette2 db ", then press any key", endl, 0

str_commands db endl, "List of commands:", endl, 0
str_a db "a:", 0
    db 0x1, "Set drive to drive A: (drive #0)", endl, 0
str_b db "b:", 0
    db 0x1, "Set drive to drive B: (drive #1)", endl, 0
str_beep db "beep", 0
    db 0x1, "Tests int 26h (beep interrupt)", endl, 0
str_cls db "cls", 0
    db 0x1, "Clear console output", endl, 0
str_del db "del", 0
    db 0x1, "Deletes a file from the disk directory", endl, 0
str_dir db "dir", 0
    db 0x1, "List files on the disk directory", endl, 0
str_echo db "echo", 0
    db 0x1, "Repeats what the user wants (useless because there's no piping)", endl, 0
str_help db "help", 0
    db 0x1, ", "
str_cmds db "cmds", 0
    db 0x1, "List available commands and their functions", endl, 0
str_reboot db "reboot", 0
    db 0x1, "Reboots the system", endl, 0
str_throw db "throw", 0
    db 0x1, "Throws specified error (hex code)", 0
str_ttyc db "tty/c", 0
    db 0x1, "Set the tty mode to VGA", endl, 0
str_ttys db "tty/s", 0
    db 0x1, "Set the tty mode to serial", endl, 0
str_type db "type", 0
    db 0x1, "Read a file out to the console", endl, 0
db endl, 0
db 0

error_not_command_or_file db "Not a command nor an executable file", endl, 0
error_not_file db "File does not exist", endl, 0
error_drive_missing db "Disk is not inserted into the drive", endl, 0
error_invalid_executable db "Invalid executable file.", endl, 0

buffer db 56 dup(0)
BUFFER_END = $
    ; allow some extra space for .exe autofill
db 4 dup(0)
db 0
BUFFER_SPACE_END = $

;==============================================================================
; Main program
;==============================================================================

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl

line:
    lea di, [buffer]
    call clear_buffer
    xor ah, ah
    mov bl, 0xf
    lea si, [msg_command]
    int 0x21
.loop:
    xor ah, ah
    int 0x16
    cmp al, 0xd
    je line_done
    cmp al, 0x8
    je .backspace
    cmp di, BUFFER_END
    jnb .loop
    mov ah, 0x1
    mov bl, 0xf
    int 0x21
    mov [di], al
    inc di
    mov byte [di], 0
    jmp .loop
.backspace:
    cmp di, buffer
    jna .loop
    mov ah, 0x1
    mov bl, 0xf
    int 0x21
    mov al, " "
    int 0x21
    mov al, 0x8
    int 0x21
    dec di
    mov byte [di], 0
    jmp .loop

line_done:
    mov ah, 0x14
    int 0x21

    cmp di, buffer
    je line

    push di

    lea si, [buffer]
    call case_down

    lea di, [str_dir]
    call strcmp
    or al, al
    jz dir

    lea di, [str_type]
    mov bl, " "
    call strcmp_until_delimiter
    or al, al
    jz type

    lea di, [str_del]
    mov bl, " "
    call strcmp_until_delimiter
    or al, al
    jz del

    lea di, [str_echo]
    mov bl, " "
    call strcmp_until_delimiter
    or al, al
    jz echo

    lea di, [str_throw]
    mov bl, " "
    call strcmp_until_delimiter
    or al, al
    jz throw

    lea di, [str_help]
    call strcmp
    or al, al
    jz help
    lea di, [str_cmds]
    call strcmp
    or al, al
    jz help

    lea di, [str_cls]
    call strcmp
    or al, al
    jz cls

    lea di, [str_beep]
    call strcmp
    or al, al
    jz beep

    lea di, [str_a]
    call strcmp
    or al, al
    jz a

    lea di, [str_b]
    call strcmp
    or al, al
    jz b

    lea di, [str_reboot]
    call strcmp
    or al, al
    jnz .what
    jmp 0xffff:0x0000
.what:

    lea di, [str_ttyc]
    call strcmp
    or al, al
    jz ttyc

    lea di, [str_ttys]
    call strcmp
    or al, al
    jz ttys

    pop di

    jmp exec

;==============================================================================
; String routines
;==============================================================================

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
    test al, al
    jz .endofstring
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

strcmp_until_di_end:
    push si
    push di
.loop:
    mov al, [si]
    mov ah, [di]
    inc si
    inc di
    test ah, ah
    jz .endofstring
    cmp al, ah
    jne .notequal
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

strcmp_until_delimiter:
    push si
    push di
.loop:
    mov al, [si]
    mov ah, [di]
    inc si
    inc di
    cmp al, bl
    je .endofstring
    test al, al
    jz .endofstring
    cmp al, ah
    jne .notequal
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

strcmp_dont_preserve_si:
    push di
.loop:
    mov al, [si]
    mov ah, [es:di]
    inc si
    inc di
    cmp al, ah
    jne .notequal
    test al, al
    jz .endofstring
    jmp .loop
.endofstring:
    xor ax, ax
    jmp .done
.notequal:
    mov ax, 1
    jmp .done
.done:
    pop di
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

case_down:
    push ax
    push si
    cld
.loop:
    lodsb

    test al, al
    jz .print
    cmp al, 'A'
    jb .loop
    cmp al, 'Z'
    ja .loop

    add al, 'a' - 'A'
    mov [si-1], al
    
    jmp .loop
.print:
    pop si
    pop ax
    ret

hex2byte:
    push si
    push bx
    xor bx, bx
    lodsb
    call .hex_nibble
    jc .error
    shl al, 4
    mov bl, al
    lodsb
    call .hex_nibble
    jc .error
    or bl, al
    mov al, bl
    pop bx
    pop si
    ret
.error:
    xor al, al
    pop bx
    pop si
    ret
.hex_nibble:
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .check_lower
    cmp al, 'F'
    jbe .upper
    jmp .check_lower
.check_lower:
    cmp al, 'a'
    jb .bad
    cmp al, 'f'
    ja .bad
    sub al, 'a' - 10
    clc
    ret
.digit:
    sub al, '0'
    clc
    ret
.upper:
    sub al, 'A' - 10
    clc
    ret
.bad:
    stc
    ret

;==============================================================================
; Misc routines
;==============================================================================

clear_buffer:
    push ax
    push di
    xor al, al
.loop:
    mov [di], al
    inc di
    cmp di, BUFFER_SPACE_END
    ja .done
    jmp .loop
.done:
    pop di
    pop ax
    ret

find_zero:
    push ax
    cld
.loop:
    lodsb
    test al, al
    jnz .loop
    pop ax
    ret

;==============================================================================
; Command routines
;==============================================================================

throw:
    add si, 6
    call hex2byte
    int 0xff

cls:
    mov ah, 0x10
    mov bl, 0xf
    int 0x21

    jmp line

del:
    pusha ; macro

    mov ah, 0x7
    add si, 4
    mov dl, [drive]
    int 0x21
    test di, di
    jz .not_exist
    mov ah, 0xa
    int 0x21

    popa ; macro
    jmp line
.not_exist:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_file]
    int 0x21

    popa
    jmp line

dir:
    pusha ; macro
    push ds

    mov ah, 0x14
    int 0x21
    xor ah, ah
    lea si, [msg_directory_of]
    int 0x21
    inc ah
    ; holds drive letter conveniently
    mov al, [msg_command]
    int 0x21
    mov ah, 0x14
    int 0x21

    xor ax, ax
    mov ds, ax
    lea di, [0x800]
    mov bl, 0xf
    xor dx, dx
    xor bp, bp
.loop:
    xor ah, ah

    inc bp
    cmp bp, 25
    jne .continue_on_with_life
    int 0x16
    
    xor ah, ah
.continue_on_with_life:
    mov al, [di]
    cmp al, 0
    je .done
    add di, 4
    mov al, [di]
    cmp al, 0
    je .skip

    mov ah, 0x14
    int 0x21

    xor ah, ah
    mov si, di
    int 0x21

    xor cx, cx
    mov cl, [di-2]
    add dx, cx
.skip:
    dec di
    mov al, [di]
    xor ah, ah
    add di, ax
    inc di
    jmp .loop
.done:
    pop ds

    mov ah, 0x14
    int 0x21

    inc bp
    cmp bp, 25
    jne .L1
    xor ah, ah
    int 0x16
.L1:
    xor ah, ah
    mov bl, 0xf
    lea si, [msg_sectors_used]
    int 0x21

    mov ah, 0xd
    mov cx, dx
    shr cx, 1
    int 0x21

    mov ah, 0x1
    mov al, "k"
    int 0x21
    mov al, "b"
    int 0x21

    mov ah, 0x14
    int 0x21
    inc bp
    cmp bp, 25
    jne .L2
    xor ah, ah
    int 0x16
    mov ah, 0x14
.L2:
    int 0x21
    inc bp
    cmp bp, 25
    jne .L3
    xor ah, ah
    int 0x16
.L3:
    popa ; macro
    jmp line

beep:
    int 0x26
    jmp line

a:
    mov al, "A"
    mov bl, [msg_command]
    cmp bl, al
    je line
    xor dl, dl
    jmp set_drive

b:
    mov al, "B"
    mov bl, [msg_command]
    cmp bl, al
    je line
    mov dl, 1

set_drive:
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
    jc drive_empty
    pop es
    popa ; macro
    mov byte [drive], dl
    mov byte [msg_command], al
    mov ah, 0x9
    int 0x21
    mov ah, 0x14
    int 0x21
    jmp line

drive_empty:
    xor ah, ah
    mov bl, 0x4
    lea si, [error_drive_missing]
    int 0x21
    jmp line

drive_invalid_fs:
    mov al, 5
    int 0xff

floppy_error:
    mov al, 4
    int 0xff

help:
    mov ah, 0x4
    mov bl, 0xf
    lea si, [str_commands]
.loop:
    int 0x21
    mov al, [si]
    test al, al
    jz line
    cmp al, 0x1
    je .line_up
    jmp .loop
.line_up:
    mov ah, 0xc
    int 0x21
    mov dl, 8
    mov ah, 0xb
    int 0x21
    inc si
    mov ah, 0x4
    jmp .loop

echo:
    add si, 5
    xor ah, ah
    mov bl, 0x7
    int 0x21
    mov ah, 0x14
    int 0x21
    jmp line

exec:
    mov ah, 0x7
    int 0x21
    test di, di
    jz .check_autofill
    push ax
    push si
    call find_zero
    sub si, 5
    mov ax, [si]
    cmp ax, ".E"
    jne .unknown_format_a
    mov ax, [si+2]
    cmp ax, "XE"
    jne .unknown_format_a
    pop si
    pop ax
.after_autofill_check:
    mov dl, [drive]
    lea bx, [0x2000]
    mov ax, cs
    cmp bx, ax
    jne .after_error
    mov al, 1
    int 0xff
.after_error:
    xor ah, ah
    int 0x24
    mov ah, 0x8
    mov es, bx
    xor bx, bx
    int 0x21

    call .get_starting_point
    pusha ; macro
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

    popa
    jmp .done
.not_exist:
    mov ax, cs
    mov ds, ax
    
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_command_or_file]
    int 0x21
.done:
    mov ax, cs
    mov ds, ax
    mov es, ax

    jmp line
.unknown_format_a:
    pop si
    pop ax
.unknown_format:
    mov ax, cs
    mov ds, ax

    xor ah, ah
    mov bl, 0x4
    lea si, [error_invalid_executable]
    int 0x21

    jmp .done
.check_autofill:
    push si
.find_terminator_loop:
    inc si
    cmp byte [si-1], 0
    jne .find_terminator_loop
    mov word [si-1], ".E"
    mov word [si+1], "XE"
    pop si

    mov ah, 0x7
    int 0x21
    test di, di
    jz .not_exist

    jmp .after_autofill_check
.get_starting_point:
    mov ax, [es:0x0]
    cmp ax, "AD"
    jne .check_es
    mov al, [es:0x2]
    cmp al, 0x2
    jne .unknown_format
    mov ax, [es:0x4]
    ret
.check_es:
    cmp ax, "ES"
    jne .unknown_format
    mov ax, [es:0x2]
    ret

type:
    pusha ; macro
    
    push ds
    push es

    add si, 5
    mov ah, 0x7
    int 0x21
    test di, di
    jz .not_exist
    xor ah, ah
    int 0x24
    mov ah, 0x8
    mov dl, [drive]
    lea bx, [0x3000]
    mov es, bx
    xor bx, bx
    int 0x21

    mov ax, es
    mov ds, ax

    xor ah, ah
    mov bl, 0xf
    lea si, [0x0]
    int 0x21

    jmp .done
.not_exist:
    mov ax, cs
    mov ds, ax
    
    xor ah, ah
    mov bl, 0x4
    lea si, [error_not_file]
    int 0x21
.done:
    pop es
    pop ds

    popa ; macro
    jmp line

ttyc:
    mov ah, 0xe
    mov al, MODE_VGA
    int 0x21

    jmp line

ttys:
    mov ah, 0xe
    mov al, MODE_SERIAL
    int 0x21

    jmp line