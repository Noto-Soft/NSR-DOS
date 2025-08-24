PIT_CONTROL      equ 0x43
PIT_CHANNEL2     equ 0x42
PORT_SPEAKER     equ 0x61

PIT_BASE_FREQ    equ 1193180

set_speaker_freq:
    push dx
    push bx
    push cx
    push eax

    mov bx, ax
    cmp bx, 0
    jz .done

    mov eax, 1193180
    xor edx, edx
    div ebx

    cmp eax, 0x10000
    jb  .ok
    mov eax, 0xFFFF
.ok:
    mov cx, ax

    mov al, 10110110b
    out 0x43, al

    mov ax, cx
    out 0x42, al
    mov al, ah
    out 0x42, al
.done:
    pop eax
    pop cx
    pop bx
    pop dx
    ret

speaker_on:
    push ax
    in al, PORT_SPEAKER
    or al, 00000011b
    out PORT_SPEAKER, al
    pop ax
    ret

speaker_off:
    push ax
    in al, PORT_SPEAKER
    and al, 11111100b
    out PORT_SPEAKER, al
    pop ax
    ret

; ax - freq
; ecx - time (in microseconds)
; DOES NOT STOP PC SPEAKER AUTOMATICALLY! YOU MUST DO YOURSELF!
play_for:
    push ax
    push ecx
    push dx
    call set_speaker_freq
    call speaker_on
    mov ah, 0x86
    mov dx, cx
    shr ecx, 16
    int 0x15
    pop dx
    pop ecx
    pop ax
    ret

; ecx - time (in microseconds)
delay_for:
    push ax
    push ecx
    push dx
    mov ah, 0x86
    mov dx, cx
    shr ecx, 16
    int 0x15
    pop dx
    pop ecx
    pop ax
    ret