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


string_proc_list_create_asm:
    push rbp
    mov rbp, rsp

    ; malloc(sizeof(string_proc_list)) → asumimos que son 2 punteros = 16 bytes
    mov rdi, 16            ; malloc(16)
    call malloc            ; devuelve puntero en rax

    test rax, rax          ; ¿es NULL?
    je .return_null        ; si sí, saltamos al final con NULL

    ; Inicializar first y last a NULL
    mov qword [rax], NULL       ; list->first = NULL
    mov qword [rax + 8], NULL   ; list->last  = NULL

    ; retornar el puntero en rax (ya está)
    pop rbp
    ret

.return_null:
    mov rax, NULL
    pop rbp
    ret

string_proc_node_create_asm:
    push rbp
    push r15
    push r14
    mov rbp, rsp
    
    ; Guardamos argumentos pero usamos solo el byte bajo para type
    movzx r15, dil         ; r15 = rdi (zero-extended de 8 bits a 64)
    mov r14, rsi           ; r14 = hash (puntero de 64 bits)

    ; malloc(sizeof(string_proc_node)) → asumimos 32 bytes
    mov rdi, 32
    call malloc              ; rax = puntero al nodo

    test rax, rax
    je .return_null          ; si malloc devuelve NULL → return NULL

    ; Inicializamos los campos
    mov qword [rax], NULL        ; node->next = NULL
    mov qword [rax + 8], NULL    ; node->previous = NULL
    mov byte [rax + 16], r15b    ; node->type = type (uint8_t) - CORREGIDO: usa r15b
    mov qword [rax + 24], r14    ; node->hash = hash

    ; Devolvemos el puntero al nodo en rax
    pop r14
    pop r15
    pop rbp
    ret

.return_null:
    mov rax, NULL
    pop r14
    pop r15
    pop rbp
    ret

string_proc_list_add_node_asm:
    push rbp
    push r15
    push r14
    push r13
    mov rbp, rsp
    sub rsp, 8

    ; Guardamos los argumentos en registros seguros
    mov r15, rdi               ; list
    movzx r14, sil             ; type (extiendo uint8_t a 64 bits con zero-extension)
    mov r13, rdx               ; hash

    ; Llamamos a string_proc_node_create_asm(type, hash)
    mov dil, r14b              ; type → en dil (byte bajo de rdi)
    mov rsi, r13               ; hash → en rsi
    call string_proc_node_create_asm

    test rax, rax
    je .end                    ; Si node == NULL, salir

    ; rax → puntero al nuevo nodo
    ; r15 → list

    ; Verificamos si list->first == NULL
    mov rcx, [r15]             ; rcx = list->first
    test rcx, rcx
    je .empty_list             ; si es NULL, la lista está vacía

.not_empty:
    ; list->last->next = node
    mov rdx, [r15 + 8]         ; rdx = list->last
    mov [rdx], rax             ; rdx->next = node

    ; node->previous = list->last
    mov [rax + 8], rdx         ; node->previous = list->last

    ; list->last = node
    mov [r15 + 8], rax

    jmp .end

.empty_list:
    ; list->first = node
    mov [r15], rax

    ; list->last = node
    mov [r15 + 8], rax

.end:
    add rsp, 8
    pop r13
    pop r14
    pop r15
    pop rbp
    ret

string_proc_list_concat_asm:
    push rbp
    push r15
    push r14
    push r13
    push r12
    push rbx                   ; Guardar rbx en la pila
    mov rbp, rsp
    sub rsp, 8                 ; alineación para llamadas

    ; Guardamos argumentos
    mov r15, rdi               ; list
    movzx r14, sil             ; type (uint8_t) con zero-extension
    mov r13, rdx               ; hash externo

    ; malloc(1)
    mov rdi, 1
    call malloc                ; rax = new_hash
    mov r12, rax               ; r12 = new_hash

    test r12, r12              ; Verificar que malloc no devolvió NULL
    je .return_null

    ; new_hash[0] = '\0'
    mov byte [r12], 0

    ; current_node = list->first
    mov rbx, [r15]

.loop:
    test rbx, rbx
    je .check_hash

    ; if (current_node->type == type)
    movzx eax, byte [rbx + 16] ; cargar type del nodo con zero-extension
    cmp al, r14b               ; comparar con type que buscamos
    jne .next_node

    ; str_concat(new_hash, current_node->hash)
    mov rdi, r12
    mov rsi, [rbx + 24]
    call str_concat

    ; free(new_hash)
    mov rdi, r12
    call free

    ; new_hash = temp
    mov r12, rax

.next_node:
    mov rbx, [rbx]             ; current_node = current_node->next
    jmp .loop

.check_hash:
    test r13, r13
    je .done

    ; str_concat(hash, new_hash)
    mov rdi, r13
    mov rsi, r12
    call str_concat

    ; free(new_hash)
    mov rdi, r12
    call free

    ; new_hash = temp
    mov r12, rax

.done:
    mov rax, r12
    add rsp, 8
    pop rbx
    pop r12
    pop r13
    pop r14
    pop r15
    pop rbp
    ret

.return_null:                  ; Añadido manejo de error si malloc falla
    mov rax, NULL
    add rsp, 8
    pop rbx
    pop r12
    pop r13
    pop r14
    pop r15
    pop rbp
    ret