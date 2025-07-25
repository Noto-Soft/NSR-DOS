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

%imacro movzx 2
    %define dst %1
    %define src %2

    %ifidn dst, ax
        %define dstl al
        %define dsth ah
    %elifidn dst, bx
        %define dstl bl
        %define dsth bh
    %elifidn dst, cx
        %define dstl cl
        %define dsth ch
    %elifidn dst, dx
        %define dstl dl
        %define dsth dh
    %else
        %error "movzx: unsupported destination register"
    %endif

    %ifidn src, dstl
        xor dsth, dsth
    %else
        mov dstl, src
        xor dsth, dsth
    %endif

    %undef dstl
    %undef dsth
    %undef dst
    %undef src
%endmacro
