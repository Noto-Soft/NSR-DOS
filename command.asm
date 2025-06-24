bits 16

org 0x0

mov ax, cs
mov ds, ax
mov es, ax
xor ah, ah
mov bl, 0xf
lea si, [msg_command_com]
int 0x21
mov ah, 0xff
int 0x21

msg_command_com: db "Hello from COMMAND.COM!", 0

times 1024-($-$$) db 0