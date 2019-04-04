BITS 64

%macro stack_all 0
    push rdi
    push rsi
    push rdx
    push r10
    push r8
    push r9
%endmacro

%macro unstack_all 0
    pop r9
    pop r8
    pop r10
    pop rdx
    pop rsi
    pop rdi
%endmacro

%define DT_DIR 4

SECTION .text
GLOBAL _start

; args: rdi, rsi, rdx, r10, r8, r9
_start:
    mov rdi, [rsp+16]
    mov rsi, 0
    call add_sufix
    mov rdi, rax ; null_pos
    stack_all
    call has_slash
    unstack_all
    mov r10, rax ; has_slash
    cmp r10, 0
    je .without_slash
    .with_slash:
        stack_all
        call rem_last_char
        unstack_all
        mov rdi, rax

    .without_slash:
    stack_all
    mov rdi, path
    call lstat
    unstack_all
    cmp rax, 0
    je .exists

    .not_exists:
        cmp r10, 0
        je .original
        .non_original:
            stack_all
            call add_slash
            unstack_all
            mov rdi, rax
        .original:
        call write_non_existent
        call exit

    .exists:
    mov eax, DWORD [stat+24]
    and eax, 0xf000
    and eax, 0x4000
    cmp eax, 0
    jg .directory
        cmp r10, 0
        je .without_slash_1
        .with_slash_1:
            call add_slash
            call write_not_dir
            call exit
        .without_slash_1:
            mov rdi, path
            call write
            call exit

    .directory:
    stack_all
    call add_slash
    unstack_all
    mov rsi, rax
    call find_rec
    call exit

; rdi=path*
; return rax=0 if exists -1 oth
lstat:
    mov rax, 6
    mov rsi, stat
    sub rsp, 8
    syscall 
    add rsp, 8
    ret  

write_non_existent:
    mov rdi, pref
    call pure_write
    mov rdi, path
    call pure_write
    mov rdi, suf_bad
    call pure_write
    ret

write_not_dir:
    mov rdi, pref
    call pure_write
    mov rdi, path
    call pure_write
    mov rdi, suf_not
    call pure_write
    ret

; rdi=null_pos
; ret rax=1 if has slash
has_slash:
    mov al, BYTE [path+rdi-1]
    cmp al, 47
    je .has
    mov rax, 0
    ret
    .has:
    mov rax, 1
    ret

; rdi=null_pos
; ret rax = new_null_pos
rem_last_char:
    mov [path+rdi-1], BYTE 0
    lea rax, [rdi-1]
    ret

; rdi=null_pos
; ret rax=new_null_pos
add_slash:
    mov [path+rdi], BYTE 47
    lea rax, [rdi+1]
    mov [path+rax], BYTE 0
    ret

; rdi=unused rsi=null_pos
find_rec:
    stack_all
    mov rdi, path
    call open
    unstack_all
    cmp rax, 0
    jge .continue
    ret
    .continue:
    mov r8, rax ; fd
    stack_all
    mov rdi, r8
    call getdents
    unstack_all

    stack_all
    mov rdi, rax
    call list
    unstack_all

    mov rdi, rax
    call close
    ret

; rdi=bytes rsi=null_pos r8=fd
; ret rax=new_fd
list:
    mov r10, 0 ; current dirent offset
    .loop:
        stack_all
        lea rdi, [dirp+r10+19]
        call check_dots
        unstack_all
        cmp rax, 1
        je .increment


        stack_all
        lea rdi, [dirp+r10+19]
        call add_sufix
        unstack_all
        mov rdx, rax
        
        stack_all
        mov rdi, path
        call write
        unstack_all

        mov al, BYTE [dirp+r10+18] ; type
        cmp al, DT_DIR
        jne .increment
        .directory:
        stack_all
        mov rdi, rdx
        call add_slash
        unstack_all

        stack_all
        mov rsi, rax
        call find_rec
        unstack_all

        mov [path+rsi], BYTE 0

        stack_all
        mov rdi, r8
        mov rsi, path
        call restart_fd
        unstack_all
        mov r8, rax

        stack_all
        mov rdi, r8
        call getdents
        unstack_all
        mov rdi, rax

        .increment:
        mov rax, 0
        mov ax, [dirp+r10+16]
        add r10, rax
        cmp r10, rdi
        jl .loop 
        mov rax, r8
    ret

; rdi=suffix* rsi=null_pos
; ret rax=new_null_pos
add_sufix:
    stack_all
    call strlen
    unstack_all
    lea r10, [rsi+rax]
    lea rdx, [rax+1]
    mov r9, rdi
    lea rdi, [path+rsi]
    mov rsi, r9
    stack_all
    call memcpy
    unstack_all
    mov rax, r10
    ret

; rdi=target* rsi=source* rdx=bytes
memcpy:
    mov r10, 0 ; i
    .loop:
        cmp r10, rdx
        jge .end
        mov al, BYTE [rsi+r10]
        mov BYTE [rdi+r10], al
        inc r10
        jmp .loop
    .end:
    ret

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

; rdi=buf*
; ret rax=1 if buf* is dotted
check_dots:
    stack_all
    call strlen
    unstack_all
    cmp rax, 1
    jne .more
    .one:
    mov dl, BYTE [rdi]
    cmp dl, 46
    je .bad
    jmp .ok
    .more:
    cmp rax, 2
    jne .ok
    mov dl, BYTE [rdi]
    cmp dl, 46
    jne .ok
    mov dl, BYTE [rdi+1]
    cmp dl, 46
    je .bad
    .ok:
    mov rax, 0
    ret
    .bad:
    mov rax, 1
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

;rdi=fd rsi=path*
;ret rax=new_fd
restart_fd:
    call close
    mov rdi, rsi
    call open
    ret

; rdi=fd
; ret rax=bytes
getdents:
    mov rax, 217
    mov rsi, dirp
    mov rdx, 4096
    sub rsp, 8
    syscall
    add rsp, 8
    ret

; rdi=buf*
pure_write:
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
    ret 

; rdi=buf*
write:
    call pure_write
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

exit:
    mov rax, 60
    mov rdi, 0
    syscall

SECTION .bss

dirp: resb 4096
path: resb 4096
stat: resb 4096

SECTION .data

endl: db "", 10, 0
pref: db "find: ‘" , 0, 0
suf_bad: db "’: No such file or directory", 10, 0
suf_not: db "’: Not a directory", 10, 0