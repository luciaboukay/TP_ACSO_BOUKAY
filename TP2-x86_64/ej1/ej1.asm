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

; string_proc_list_create_asm:
;   Creates a new empty string_proc_list
;   Returns:
;     rax - pointer to new list, or NULL on failure
string_proc_list_create_asm:
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    
    ; Llamar a malloc para crear la lista
    mov rdi, 16       ; sizeof(string_proc_list) = 16 bytes (2 punteros de 8 bytes)
    call malloc
    
    ; Verificar si malloc falló
    test rax, rax
    jz .return_null
    
    ; Inicializar campos de la lista
    mov qword [rax], NULL    ; list->first = NULL
    mov qword [rax+8], NULL  ; list->last = NULL
    jmp .end
    
.return_null:
    xor eax, eax      ; Devolver NULL
    
.end:
    ; Epílogo de función
    leave
    ret

; string_proc_node_create_asm:
;   Creates a new string_proc_node
;   Parameters:
;     dil - type
;     rsi - hash (string pointer)
;   Returns:
;     rax - pointer to new node, or NULL on failure
string_proc_node_create_asm:
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    
    ; Verificar si hash es NULL primero
    test rsi, rsi
    jz .return_null
    
    ; Llamar a malloc para crear el nodo
    mov rdi, 32       ; sizeof(string_proc_node) = 32 bytes (3 punteros + uint8_t + padding)
    call malloc
    
    ; Verificar si malloc falló
    test rax, rax
    jz .return_null
    
    ; Inicializar campos del nodo
    mov qword [rax], NULL     ; node->next = NULL
    mov qword [rax+8], NULL   ; node->previous = NULL
    mov byte [rax+16], dil    ; node->type = type
    mov qword [rax+24], rsi   ; node->hash = hash
    jmp .end
    
.return_null:
    xor eax, eax      ; Devolver NULL
    
.end:
    ; Epílogo de función
    pop rbp
    ret

; string_proc_list_add_node_asm:
;   Adds a new node to the list
;   Parameters:
;     rdi - list pointer
;     sil - type
;     rdx - hash (string pointer)
;   Returns:
;     rax - TRUE (1) on success, FALSE (0) on failure
string_proc_list_add_node_asm:
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    push r12
    push r13
    
    ; Guardar parámetros
    mov r12, rdi       ; list
    mov r13, rdx       ; hash
    
    ; Verificar si list es NULL
    test r12, r12
    jz .error_end
    
    ; Llamar a string_proc_node_create_asm(type, hash)
    movzx edi, sil     ; Extender type de 8 bits a 32 bits
    mov rsi, r13       ; hash
    call string_proc_node_create_asm
    
    ; Verificar si la creación del nodo falló
    test rax, rax
    jz .error_end
    
    ; Guardar el puntero al nodo creado
    mov r13, rax       ; node
    
    ; Verificar si la lista está vacía (list->first == NULL)
    cmp qword [r12], NULL
    jne .list_not_empty
    
    ; Si la lista está vacía
    mov [r12], r13          ; list->first = node
    mov [r12+8], r13        ; list->last = node
    jmp .success
    
.list_not_empty:
    ; Si la lista no está vacía
    mov rax, [r12+8]        ; rax = list->last
    mov [rax], r13          ; list->last->next = node
    mov [r13+8], rax        ; node->previous = list->last
    mov [r12+8], r13        ; list->last = node
    
.success:
    mov eax, TRUE           ; Return TRUE
    jmp .end
    
.error_end:
    xor eax, eax            ; Return FALSE
    
.end:
    ; Epílogo de función
    pop r13
    pop r12
    pop rbp
    ret
    
string_proc_list_concat_asm:
    ; Prologue
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save parameters
    mov rbx, rdi       ; list
    movzx r12d, sil    ; type (zero-extend to avoid potential issues)
    mov r13, rdx       ; prefix hash

    ; Check for NULL list
    test rbx, rbx
    jz .return_null

    ; Create initial empty string
    mov rdi, 1
    call malloc
    test rax, rax
    jz .return_null
    mov byte [rax], 0
    mov r14, rax        ; r14 = accumulated string

    ; Start with first node
    mov r15, [rbx]      ; current = list->first

.node_loop:
    ; Check if current node is NULL
    test r15, r15
    jz .prefix_handling

    ; Check type match - Compare the correct byte
    movzx eax, byte [r15+16]  ; current->type (offset might need adjustment)
    cmp eax, r12d             ; Compare with requested type
    jne .next_node

    ; Get current node's hash
    mov rsi, [r15+24]   ; current->hash
    test rsi, rsi       ; Check if hash is NULL
    jz .next_node

    ; Concatenate: result = str_concat(accumulated, current->hash)
    mov rdi, r14        ; accumulated string
    call str_concat
    test rax, rax       ; Check if concatenation failed
    jz .concat_fail

    ; Replace old string with new concatenated one
    mov rdi, r14
    mov r14, rax
    call free

.next_node:
    mov r15, [r15]      ; current = current->next
    jmp .node_loop

.prefix_handling:
    ; Apply prefix if provided
    test r13, r13
    jz .return_result

    ; Concatenate: result = str_concat(prefix, accumulated)
    mov rdi, r13        ; prefix
    mov rsi, r14        ; accumulated string
    call str_concat
    test rax, rax
    jz .concat_fail

    ; Free the old accumulated string
    mov rdi, r14
    mov r14, rax
    call free

.return_result:
    mov rax, r14
    jmp .end

.concat_fail:
    ; Cleanup if concatenation failed
    test r14, r14
    jz .return_null
    mov rdi, r14
    call free

.return_null:
    xor eax, eax

.end:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret