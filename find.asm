BITS 64

%macro stack_all 0
    push rdi
    push rsi
    push rdx
%endmacro

%macro unstack_all 0
    pop rdx
    pop rsi
    pop rdi
%endmacro

SECTION .text
GLOBAL _start
; args: rdi, rsi, rdx, r10, r8, r9
_start:
    mov rdi, [rsp+16]
    ; call write
    call open
    mov r8, rax ; fd
    mov rdi, r8
    call getdents
    mov rdi, rax
    call ls
    call exit

; rdi=buf*
strlen:
    mov rax, 0 ; i
    mov dl, 0
    .loop:
        mov dl, BYTE [rdi+rax]
        inc rax
        cmp dl, 0
        jne .loop
    dec rax
    ret


; rdi=path*
; ret rax=fd
open:
    mov rax, 2
    mov rsi, 0
    mov rdx, 0
    sub rsp, 8
    syscall
    add rsp, 8
    ret

; rdi=fd
close:
    mov rax, 3
    sub rsp, 8
    syscall
    add rsp, 8
    ret

; rdi=fd
; ret rax=bytes
getdents:
    mov rax, 78
    mov rsi, dirp
    mov rdx, 4096
    sub rsp, 8
    syscall
    add rsp, 8
    ret

; rdi=buf*
write:
    stack_all
    call strlen
    unstack_all
    mov rdx, rax
    mov rsi, rdi
    mov rdi, 1
    mov rax, 1
    sub rsp, 8
    syscall
    add rsp, 8
    call write_endl
    ret

write_endl:
    mov rax, 1
    mov rdi, 1
    mov rsi, endl
    mov rdx, 1
    sub rsp, 8
    syscall
    add rsp, 8
    ret

; rdi=bytes
ls:
    mov rsi, 0 ; current dirent offset
    mov rdx, rdi
    .loop:
        lea rdi, [dirp+rsi+18]
        stack_all
        call write
        unstack_all
        mov rdi, 0
        mov di, [dirp+rsi+16]
        add rsi, rdi
        cmp rsi, rdx
        jl .loop 
    ret

exit:
    mov rax, 60
    mov rdi, 0
    syscall

SECTION .bss

dirp: resb 4096
num: resb 8

SECTION .data

endl: db "", 10, 0
