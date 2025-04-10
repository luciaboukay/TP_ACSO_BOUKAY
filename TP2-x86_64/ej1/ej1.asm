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

    ; malloc(sizeof(string_proc_list)) → 16 bytes (2 punteros)
    mov rdi, 16            
    call malloc            
    test rax, rax          
    je .return_null        

    ; Inicializar first y last a NULL
    mov qword [rax], NULL  ; list->first = NULL
    mov qword [rax + 8], NULL  ; list->last = NULL

    ; retornar puntero en rax
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
    
    ; Guardar argumentos
    movzx r15, dil         ; r15 = type (uint8_t)
    mov r14, rsi           ; r14 = hash (char*)
    
    ; malloc(sizeof(string_proc_node)) - 32 bytes
    mov rdi, 32
    call malloc
    test rax, rax
    je .return_null         

    ; Inicializar campos
    mov qword [rax], NULL      ; node->next = NULL
    mov qword [rax + 8], NULL  ; node->previous = NULL
    mov byte [rax + 16], r15b  ; node->type = type
    mov qword [rax + 24], r14  ; node->hash = hash

    ; retornar puntero en rax
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
    sub rsp, 8              ; alineación para llamadas
    
    ; Guardar argumentos
    mov r15, rdi            ; r15 = list
    movzx r14, sil          ; r14 = type (uint8_t)
    mov r13, rdx            ; r13 = hash
    
    ; Llamar a string_proc_node_create(type, hash)
    mov dil, r14b           ; primer arg: type
    mov rsi, r13            ; segundo arg: hash
    call string_proc_node_create_asm
    
    test rax, rax
    je .end                 ; Si el nodo es NULL, salir
    
    ; Verificar si la lista está vacía
    mov rcx, [r15]          ; rcx = list->first
    test rcx, rcx
    je .empty_list          ; si es NULL, lista vacía
    
    ; Lista no vacía: añadir al final
    mov rdx, [r15 + 8]      ; rdx = list->last
    mov [rdx], rax          ; list->last->next = node
    mov [rax + 8], rdx      ; node->previous = list->last
    mov [r15 + 8], rax      ; list->last = node
    jmp .end
    
.empty_list:
    ; Lista vacía: primer y último apuntan al nuevo nodo
    mov [r15], rax          ; list->first = node
    mov [r15 + 8], rax      ; list->last = node
    
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
    push rbx                ; guardar rbx (callee-saved)
    mov rbp, rsp
    sub rsp, 8              ; alineación para llamadas
    
    ; Guardar argumentos
    mov r15, rdi            ; r15 = list
    movzx r14, sil          ; r14 = type (uint8_t)
    mov r13, rdx            ; r13 = hash externo
    
    ; malloc(1) para new_hash inicial
    mov rdi, 1
    call malloc
    mov r12, rax            ; r12 = new_hash
    
    test r12, r12           ; verificar si malloc falló
    je .return_null
    
    ; Inicializar new_hash[0] = '\0'
    mov byte [r12], 0
    
    ; current_node = list->first
    mov rbx, [r15]          ; rbx = list->first
    
.loop:
    test rbx, rbx
    je .check_hash          ; Si no hay más nodos, salir del bucle
    
    ; Verificar si current_node->type == type
    movzx eax, byte [rbx + 16]
    cmp al, r14b
    jne .next_node
    
    ; str_concat(new_hash, current_node->hash)
    mov rdi, r12
    mov rsi, [rbx + 24]
    call str_concat
    
    ; free(new_hash)
    mov rdi, r12
    call free
    
    ; new_hash = resultado de str_concat
    mov r12, rax
    
.next_node:
    mov rbx, [rbx]          ; current_node = current_node->next
    jmp .loop
    
.check_hash:
    test r13, r13
    je .done                ; Si hash externo es NULL, terminar
    
    ; str_concat(hash, new_hash)
    mov rdi, r13
    mov rsi, r12
    call str_concat
    
    ; free(new_hash)
    mov rdi, r12
    call free
    
    ; new_hash = resultado de str_concat
    mov r12, rax
    
.done:
    mov rax, r12            ; return new_hash
    add rsp, 8
    pop rbx
    pop r12
    pop r13
    pop r14
    pop r15
    pop rbp
    ret

.return_null:
    mov rax, NULL
    add rsp, 8
    pop rbx
    pop r12
    pop r13
    pop r14
    pop r15
    pop rbp
    ret