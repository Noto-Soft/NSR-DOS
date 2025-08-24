;==============================================================================
; fasm directives
;==============================================================================

use16
org 0x0

endl equ 0xa
include "src/inc/8086.inc"

;==============================================================================
; Executable header
;==============================================================================

db "ES"
dw start
db 20 dup(0)

;==============================================================================
; Constants and variables
;==============================================================================

msg_choose_image db "Enter name of .spk file (Or leave blank for default)", endl, 0
msg_image_doesnt_exist db ".spk file requested does not exist", endl, 0

default_image db "pb95.spk", 0
image_file_name db 31 dup(0)
FILENAME_BUFFER_LENGTH = $-image_file_name
db 0

drive db ?
pre_stack dw ?

;==============================================================================
; Main program
;==============================================================================

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov [drive], dl
    mov [pre_stack], sp

main:
    xor ah, ah
    mov bl, 0x3
    lea si, [msg_choose_image]
    int 0x21

    lea di, [image_file_name]
    xor bx, bx
    mov byte [di], 0
.get_filename_loop:
    xor ah, ah
    int 0x16
    cmp al, 0xd
    je .got_filename
    cmp al, 0x8
    je .backspace
    cmp bx, FILENAME_BUFFER_LENGTH
    jnb .get_filename_loop
    mov ah, 0x1
    push bx
    mov bl, 0xf
    int 0x21
    pop bx
    mov [di+bx], al
    inc bx
    mov byte [di+bx], 0
    jmp .get_filename_loop
.backspace:
    cmp bx, 0
    jna .get_filename_loop
    mov ah, 0x1
    push bx
    mov al, 0x8
    mov bl, 0xf
    int 0x21
    pop bx
    mov byte [di+bx], 0
    dec bx
    jmp .get_filename_loop
.got_filename:
    lea si, [image_file_name]
    cmp byte [si], 0
    jne .continue

    lea si, [default_image]
    jmp .after_continue
.continue:
    mov ah, 0x14
    int 0x21
.after_continue:
    mov ah, 0x7
    int 0x21
    test di, di
    jz .not_exist
    mov ah, 0x8
    mov dl, [drive]
    mov bx, 0x3000
    mov es, bx
    xor bx, bx
    int 0x21

    xor si, si
.play_loop:
    call play_entry
    add si, 7
    cmp al, 0
    jne .play_loop

    mov sp, [pre_stack]

    retf
.not_exist:
    xor ah, ah
    mov bl, 0x4
    lea si, [msg_image_doesnt_exist]
    int 0x21

    mov sp, [pre_stack]

    retf

;==============================================================================
; NSPSMF Routines
;==============================================================================

; es:si - pointer to entry
; returns:
;   al - 0 if song is over
play_entry:
    push ax
    push ecx

    mov al, [es:si]
    cmp al, 1
    je .pcspk_off
    cmp al, 2
    je .pcspk_on
    cmp al, 3
    je .end_song
    cmp al, 4
    je .delay
    jmp .play_normal
.pcspk_off:
    call speaker_off
    jmp .play_normal
.pcspk_on:
    mov ax, [es:si+1]
    call set_speaker_freq

    call speaker_on

    jmp .delay
.play_normal:
    mov ax, [es:si+1]
    call set_speaker_freq
.delay:
    mov ecx, [es:si+3]
    call delay_for

    pop ecx
    pop ax
    ret
.end_song:
    call speaker_off
    pop ecx
    pop ax
    mov al, 0
    ret

;==============================================================================
; Includes
;==============================================================================

include "src/inc/pcspk.inc"