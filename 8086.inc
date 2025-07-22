%imacro pusha 0
    push ax
    push cx
    push dx
    push bx
    push bp
    push si
    push di
%endmacro

%imacro popa 0
    pop di
    pop si
    pop bp
    pop bx
    pop dx
    pop cx
    pop ax
%endmacro