; INCLUDE AT THE BOTTOM OF FILES

; make sure you have defined the offset of the heap from the start of free high memory (0x00180000) in a macro named HIGH_OFFSET
; program should use 0xd0000
; the heap will take up 8kb - 1b!!

;==============================================================================
; Heap routines
;==============================================================================

; cx - size in bytes
; returns: fs:esi - flat pointer
malloc:
    push ecx
    push ax
    push ebx
    lea esi, [fs:HEAP_BOTTOM]
    jmp .loop
.nextloop:
    mov bx, [fs:esi+1]
    movzx ebx, bx
    add esi, ebx
    add esi, HEAP_BLOCK_HEADER_SIZE
.loop:
    cmp esi, HEAP_TOP
    jae .fate
    push esi
    add esi, HEAP_BLOCK_HEADER_SIZE
    movzx ecx, cx
    add esi, ecx
    cmp esi, HEAP_TOP
    jae .fate2
    pop esi
    mov al, [fs:esi]
    test al, al
    jnz .nextloop
    mov bx, [fs:esi+1]
    test bx, bx
    jz .uninitialized
    cmp cx, bx
    ja .nextloop
    mov cx, bx ; for safety, use the whole block
.uninitialized:
    mov byte [fs:esi], 1
    mov [fs:esi+1], cx
.done:
    add esi, HEAP_BLOCK_HEADER_SIZE
    pop bx
    pop ax
    pop ecx
    ret
.fate2:
    pop esi
.fate:
    xor esi, esi
    pop ebx
    pop ax
    pop ecx
    ret

; zero out the allocated memory
; same as malloc  just zeros out so no garbage
zalloc:
    call malloc
    push cx
    push esi
.loop:
    mov byte [fs:esi], 0
    inc esi
    loop .loop
    pop esi
    pop cx
    ret

; fs:esi - pointer to data to free
; if invalid pointer then it just silently fails and sets al to 1
free:
    push ebx
    push cx
    push esi
    cmp esi, HEAP_BOTTOM + HEAP_BLOCK_HEADER_SIZE
    jb .fail
    cmp esi, HEAP_TOP
    ja .fail
    sub esi, HEAP_BLOCK_HEADER_SIZE
    mov byte [fs:esi], 0
    mov bx, [fs:esi+1]
    movzx ebx, bx
    mov cx, [fs:esi+ebx+HEAP_BLOCK_HEADER_SIZE+1]
    test cx, cx
    jnz .done
    mov word [fs:esi+1], 0
.done:
    pop esi
    pop cx
    pop ebx
    ret
.fail:
    mov al, 1
    pop esi
    pop cx
    pop ebx
    ret

; fs:esi - pointer to original memory
; cx - new size
; returns: fs:esi - new memory
realloc:
    push ax
    push bx
    push cx
    push edi
    mov bx, [fs:esi-HEAP_BLOCK_HEADER_SIZE+1]
    mov ax, cx
    cmp cx, bx
    jnb .larger
    mov ax, bx
.larger:
    mov edi, esi
    call zalloc
    xchg esi, edi
    mov cx, ax
    push edi
.bring_loop:
    mov al, [fs:esi]
    mov [fs:edi], al
    inc esi
    inc edi
    pop edi
    mov esi, edi
    pop edi
    pop cx
    pop bx
    pop ax
    ret

;==============================================================================
; Heap
;==============================================================================

HEAP_BOTTOM = 0x00180000 + HIGH_OFFSET
HEAP_TOP = HEAP_BOTTOM + 0x1ffff
HEAP_BLOCK_HEADER_SIZE = 3