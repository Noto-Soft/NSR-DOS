; INCLUDE AT THE BOTTOM OF FILES

;==============================================================================
; Heap routines
;==============================================================================

; cx - size in bytes
; returns: si - pointeer
malloc:
    push ax
    push bx
    lea si, [HEAP_BOTTOM]
    jmp .loop
.nextloop:
    mov bx, [si+1]
    add si, bx
    add si, HEAP_BLOCK_HEADER_SIZE
.loop:
    cmp si, HEAP_TOP
    jae .fate
    push si
    add si, HEAP_BLOCK_HEADER_SIZE
    add si, cx
    cmp si, HEAP_TOP
    jae .fate2
    pop si
    mov al, [si]
    test al, al
    jnz .nextloop
    mov bx, [si+1]
    test bx, bx
    jz .uninitialized
    cmp cx, bx
    ja .nextloop
    mov cx, bx ; for safety, use the whole block
.uninitialized:
    mov byte [si], 1
    mov [si+1], cx
.done:
    add si, HEAP_BLOCK_HEADER_SIZE
    pop bx
    pop ax
    ret
.fate2:
    pop si
.fate:
    xor si, si
    pop bx
    pop ax
    ret

; zero out the allocated memory
; same as malloc  just zeros out so no garbage
zalloc:
    call malloc
    push cx
    push si
.loop:
    mov byte [si], 0
    inc si
    loop .loop
    pop si
    pop cx
    ret

; si - pointer to data to free
; if invalid pointer then it just silently fails and sets al to 1
free:
    push bx
    push cx
    push si
    cmp si, HEAP_BOTTOM + HEAP_BLOCK_HEADER_SIZE
    jb .fail
    cmp si, HEAP_TOP
    ja .fail
    sub si, HEAP_BLOCK_HEADER_SIZE
    mov byte [si], 0
    mov bx, [si+1]
    mov cx, [si+bx+HEAP_BLOCK_HEADER_SIZE+1]
    test cx, cx
    jnz .done
    mov word [si+1], 0
.done:
    pop si
    pop cx
    pop bx
    ret
.fail:
    mov al, 1
    pop si
    pop cx
    pop bx
    ret

; si - pointer to original memory
; cx - new size
; returns: si - new memory
realloc:
    push ax
    push bx
    push cx
    push di
    mov bx, [si-HEAP_BLOCK_HEADER_SIZE+1]
    mov ax, cx
    cmp cx, bx
    jnb .larger
    mov ax, bx
.larger:
    mov di, si
    call zalloc
    xchg si, di
    mov cx, ax
    push di
    rep movsb
    pop di
    mov si, di
    pop di
    pop cx
    pop bx
    pop ax
    ret

;==============================================================================
; Heap
;==============================================================================

HEAP_BOTTOM = $
HEAP_TOP = 0xffff
HEAP_BLOCK_HEADER_SIZE = 3