; /** defines bool y puntero **/
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data

section .text

global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

; FUNCIONES auxiliares que pueden llegar a necesitar:
extern malloc
extern free
extern str_concat

.LC0:
        .string "Error: No se pudo crear la lista"
string_proc_list_create:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 16
        mov     edi, 16
        call    malloc
        mov     QWORD PTR [rbp-8], rax
        cmp     QWORD PTR [rbp-8], 0
        jne     .L2
        mov     edi, OFFSET FLAT:.LC0
        call    puts
        mov     eax, 0
        jmp     .L3
.L2:
        mov     rax, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax], 0
        mov     rax, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax+8], 0
        mov     rax, QWORD PTR [rbp-8]
.L3:
        leave
        ret
.LC1:
        .string "Error: No se pudo crear el nodo"
string_proc_node_create:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 32
        mov     eax, edi
        mov     QWORD PTR [rbp-32], rsi
        mov     BYTE PTR [rbp-20], al
        mov     edi, 32
        call    malloc
        mov     QWORD PTR [rbp-8], rax
        cmp     QWORD PTR [rbp-8], 0
        jne     .L5
        mov     edi, OFFSET FLAT:.LC1
        call    puts
        mov     eax, 0
        jmp     .L6
.L5:
        mov     rax, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax], 0
        mov     rax, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax+8], 0
        mov     rax, QWORD PTR [rbp-8]
        movzx   edx, BYTE PTR [rbp-20]
        mov     BYTE PTR [rax+16], dl
        mov     rax, QWORD PTR [rbp-8]
        mov     rdx, QWORD PTR [rbp-32]
        mov     QWORD PTR [rax+24], rdx
        mov     rax, QWORD PTR [rbp-8]
.L6:
        leave
        ret
string_proc_list_add_node:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 48
        mov     QWORD PTR [rbp-24], rdi
        mov     eax, esi
        mov     QWORD PTR [rbp-40], rdx
        mov     BYTE PTR [rbp-28], al
        movzx   eax, BYTE PTR [rbp-28]
        mov     rdx, QWORD PTR [rbp-40]
        mov     rsi, rdx
        mov     edi, eax
        call    string_proc_node_create
        mov     QWORD PTR [rbp-8], rax
        cmp     QWORD PTR [rbp-8], 0
        jne     .L8
        mov     edi, OFFSET FLAT:.LC1
        call    puts
        jmp     .L7
.L8:
        mov     rax, QWORD PTR [rbp-24]
        mov     rax, QWORD PTR [rax]
        test    rax, rax
        jne     .L10
        mov     rax, QWORD PTR [rbp-24]
        mov     rdx, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax], rdx
        mov     rax, QWORD PTR [rbp-24]
        mov     rdx, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax+8], rdx
        jmp     .L7
.L10:
        mov     rax, QWORD PTR [rbp-24]
        mov     rax, QWORD PTR [rax+8]
        mov     rdx, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax], rdx
        mov     rax, QWORD PTR [rbp-24]
        mov     rdx, QWORD PTR [rax+8]
        mov     rax, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax+8], rdx
        mov     rax, QWORD PTR [rbp-24]
        mov     rdx, QWORD PTR [rbp-8]
        mov     QWORD PTR [rax+8], rdx
.L7:
        leave
        ret
str_concat:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 48
        mov     QWORD PTR [rbp-40], rdi
        mov     QWORD PTR [rbp-48], rsi
        mov     rax, QWORD PTR [rbp-40]
        mov     rdi, rax
        call    strlen
        mov     DWORD PTR [rbp-4], eax
        mov     rax, QWORD PTR [rbp-48]
        mov     rdi, rax
        call    strlen
        mov     DWORD PTR [rbp-8], eax
        mov     edx, DWORD PTR [rbp-4]
        mov     eax, DWORD PTR [rbp-8]
        add     eax, edx
        mov     DWORD PTR [rbp-12], eax
        mov     eax, DWORD PTR [rbp-12]
        add     eax, 1
        cdqe
        mov     rdi, rax
        call    malloc
        mov     QWORD PTR [rbp-24], rax
        mov     rdx, QWORD PTR [rbp-40]
        mov     rax, QWORD PTR [rbp-24]
        mov     rsi, rdx
        mov     rdi, rax
        call    strcpy
        mov     rdx, QWORD PTR [rbp-48]
        mov     rax, QWORD PTR [rbp-24]
        mov     rsi, rdx
        mov     rdi, rax
        call    strcat
        mov     rax, QWORD PTR [rbp-24]
        leave
        ret
string_proc_list_concat:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 64
        mov     QWORD PTR [rbp-40], rdi
        mov     eax, esi
        mov     QWORD PTR [rbp-56], rdx
        mov     BYTE PTR [rbp-44], al
        mov     rax, QWORD PTR [rbp-40]
        mov     rax, QWORD PTR [rax]
        mov     QWORD PTR [rbp-8], rax
        mov     edi, 1
        call    malloc
        mov     QWORD PTR [rbp-16], rax
        mov     rax, QWORD PTR [rbp-16]
        mov     BYTE PTR [rax], 0
        jmp     .L14
.L16:
        mov     rax, QWORD PTR [rbp-8]
        movzx   eax, BYTE PTR [rax+16]
        cmp     BYTE PTR [rbp-44], al
        jne     .L15
        mov     rax, QWORD PTR [rbp-8]
        mov     rdx, QWORD PTR [rax+24]
        mov     rax, QWORD PTR [rbp-16]
        mov     rsi, rdx
        mov     rdi, rax
        call    str_concat
        mov     QWORD PTR [rbp-32], rax
        mov     rax, QWORD PTR [rbp-16]
        mov     rdi, rax
        call    free
        mov     rax, QWORD PTR [rbp-32]
        mov     QWORD PTR [rbp-16], rax
.L15:
        mov     rax, QWORD PTR [rbp-8]
        mov     rax, QWORD PTR [rax]
        mov     QWORD PTR [rbp-8], rax
.L14:
        cmp     QWORD PTR [rbp-8], 0
        jne     .L16
        cmp     QWORD PTR [rbp-56], 0
        je      .L17
        mov     rdx, QWORD PTR [rbp-16]
        mov     rax, QWORD PTR [rbp-56]
        mov     rsi, rdx
        mov     rdi, rax
        call    str_concat
        mov     QWORD PTR [rbp-24], rax
        mov     rax, QWORD PTR [rbp-16]
        mov     rdi, rax
        call    free
        mov     rax, QWORD PTR [rbp-24]
        mov     QWORD PTR [rbp-16], rax
.L17:
        mov     rax, QWORD PTR [rbp-16]
        leave
        ret