; --- Definición de constantes ---
%define NULL 0
%define TRUE 1
%define FALSE 0

section .data
.LC0: db "Error: No se pudo crear la lista", 0
.LC1: db "Error: No se pudo crear el nodo", 0

section .text
global string_proc_list_create_asm
global string_proc_node_create_asm
global string_proc_list_add_node_asm
global string_proc_list_concat_asm

extern malloc
extern free
extern str_concat
extern puts
extern strlen
extern strcpy
extern strcat

; ------------------------------------------
; string_proc_list_create_asm:
; Crea una lista vacía (estructura con head y tail en NULL)
; Retorna: puntero a la lista o NULL si hay error
; ------------------------------------------
string_proc_list_create_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    mov edi, 16              ; reservar 16 bytes para head y tail
    call malloc
    mov qword [rbp-8], rax   ; guardar puntero a la lista

    cmp rax, 0
    jne .L2
    mov edi, .LC0            ; mensaje de error
    call puts
    mov eax, 0
    jmp .L3

.L2:
    mov rax, qword [rbp-8]
    mov qword [rax], 0       ; head = NULL
    mov qword [rax+8], 0     ; tail = NULL
    mov rax, qword [rbp-8]   ; retornar lista

.L3:
    leave
    ret

; ------------------------------------------
; string_proc_node_create_asm:
; Crea un nodo con proc_id y string
; Entradas: edi = proc_id, rsi = string
; Retorna: puntero al nodo o NULL si hay error
; ------------------------------------------
string_proc_node_create_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov eax, edi
    mov qword [rbp-32], rsi  ; guardar string
    mov byte [rbp-20], al    ; guardar proc_id

    mov edi, 32              ; reservar 32 bytes para el nodo
    call malloc
    mov qword [rbp-8], rax

    cmp rax, 0
    jne .L5
    mov edi, .LC1
    call puts
    mov eax, 0
    jmp .L6

.L5:
    mov rax, qword [rbp-8]
    mov qword [rax], 0       ; next = NULL
    mov qword [rax+8], 0     ; prev = NULL
    movzx edx, byte [rbp-20]
    mov byte [rax+16], dl    ; proc_id
    mov rdx, qword [rbp-32]
    mov qword [rax+24], rdx  ; string

.L6:
    mov rax, qword [rbp-8]
    leave
    ret

; ------------------------------------------
; string_proc_list_add_node_asm:
; Agrega un nodo al final de la lista
; Entradas:
;   rdi = puntero a la lista
;   esi = proc_id
;   rdx = string
; ------------------------------------------
string_proc_list_add_node_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 48

    mov qword [rbp-24], rdi  ; lista
    mov eax, esi
    mov qword [rbp-40], rdx  ; string
    mov byte [rbp-28], al    ; proc_id

    ; Crear nuevo nodo
    movzx eax, byte [rbp-28]
    mov rsi, qword [rbp-40]
    mov edi, eax
    call string_proc_node_create_asm
    mov qword [rbp-8], rax   ; nuevo nodo

    cmp rax, 0
    jne .L8
    mov edi, .LC1
    call puts
    jmp .L7

.L8:
    ; Si la lista está vacía
    mov rax, qword [rbp-24]
    mov rax, qword [rax]     ; head
    test rax, rax
    jne .L10

    ; Lista vacía → head y tail apuntan al nuevo nodo
    mov rax, qword [rbp-24]
    mov rdx, qword [rbp-8]
    mov qword [rax], rdx     ; head = nodo
    mov qword [rax+8], rdx   ; tail = nodo
    jmp .L7

.L10:
    ; Lista no vacía → insertar al final
    mov rax, qword [rbp-24]
    mov rax, qword [rax+8]   ; tail actual
    mov rdx, qword [rbp-8]   ; nuevo nodo
    mov qword [rax], rdx     ; tail->next = nuevo nodo
    mov qword [rdx+8], rax   ; nuevo->prev = tail
    mov rax, qword [rbp-24]
    mov qword [rax+8], rdx   ; actualizar tail

.L7:
    leave
    ret

; ------------------------------------------
; string_proc_list_concat_asm:
; Concatena los strings de todos los nodos con proc_id dado
; Entradas:
;   rdi = puntero a lista
;   esi = proc_id
;   rdx = string final a agregar (puede ser NULL)
; Retorna:
;   string concatenado (malloc'd)
; ------------------------------------------
string_proc_list_concat_asm:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov qword [rbp-40], rdi  ; lista
    mov eax, esi
    mov qword [rbp-56], rdx  ; string extra
    mov byte [rbp-44], al    ; proc_id

    ; Obtener el primer nodo
    mov rax, qword [rbp-40]
    mov rax, qword [rax]
    mov qword [rbp-8], rax

    ; Crear string vacío inicial
    mov edi, 1
    call malloc
    mov qword [rbp-16], rax
    mov byte [rax], 0

.L14:  ; loop por cada nodo
    cmp qword [rbp-8], 0
    je .L17                  ; fin de la lista

.L16:
    ; Comparar proc_id
    mov rax, qword [rbp-8]
    movzx eax, byte [rax+16]
    cmp byte [rbp-44], al
    jne .L15

    ; Concatenar string del nodo
    mov rax, qword [rbp-8]
    mov rdx, qword [rax+24]
    mov rax, qword [rbp-16]
    mov rsi, rdx
    mov rdi, rax
    call str_concat

    ; Liberar string anterior
    mov qword [rbp-32], rax
    mov rdi, qword [rbp-16]
    call free
    mov rax, qword [rbp-32]
    mov qword [rbp-16], rax

.L15:
    ; Siguiente nodo
    mov rax, qword [rbp-8]
    mov rax, qword [rax]
    mov qword [rbp-8], rax
    jmp .L14

.L17:
    ; Concatenar string final (si no es NULL)
    cmp qword [rbp-56], 0
    je .L19

    mov rdx, qword [rbp-16]
    mov rax, qword [rbp-56]
    mov rsi, rdx
    mov rdi, rax
    call str_concat

    mov qword [rbp-24], rax
    mov rdi, qword [rbp-16]
    call free
    mov rax, qword [rbp-24]
    mov qword [rbp-16], rax

.L19:
    mov rax, qword [rbp-16]  ; resultado final
    leave
    ret
