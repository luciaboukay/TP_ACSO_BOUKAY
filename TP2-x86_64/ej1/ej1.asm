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
    ; Prologue - preserve all non-volatile registers we'll use
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Initialize return value to NULL
    xor r14, r14

    ; Save parameters in non-volatile registers
    mov rbx, rdi       ; list pointer (preserved)
    mov r12b, sil      ; type (store as byte)
    mov r13, rdx       ; prefix hash (preserved)

    ; Validate list pointer
    test rbx, rbx
    jz .cleanup

    ; Create initial empty string (with null terminator)
    mov rdi, 1
    call malloc
    test rax, rax
    jz .cleanup
    mov byte [rax], 0
    mov r14, rax        ; r14 = accumulated string

    ; Load first node carefully
    mov r15, [rbx]      ; current_node = list->first
    test r15, r15
    jz .apply_prefix

.traversal_loop:
    ; Verify node type matches
    mov al, byte [r15+16]  ; node->type
    cmp al, r12b
    jne .next_node

    ; Safely get node->hash
    mov rsi, [r15+24]   ; node->hash
    test rsi, rsi
    jz .next_node

    ; Validate we have an accumulator
    test r14, r14
    jz .next_node

    ; Perform concatenation: r14 = str_concat(r14, node->hash)
    mov rdi, r14
    call str_concat
    test rax, rax
    jz .concatenation_failed

    ; Replace old string with new one
    mov rdi, r14
    mov r14, rax
    call free

.next_node:
    ; Move to next node with safety check
    mov r15, [r15]      ; node = node->next
    test r15, r15
    jnz .traversal_loop

.apply_prefix:
    ; Handle prefix if provided
    test r13, r13
    jz .prepare_result

    ; Special case: empty result but has prefix
    test r14, r14
    jz .copy_prefix_only

    ; Normal case: concat prefix + accumulated
    mov rdi, r13
    mov rsi, r14
    call str_concat
    test rax, rax
    jz .concatenation_failed

    ; Replace accumulated string
    mov rdi, r14
    mov r14, rax
    call free
    jmp .prepare_result

.copy_prefix_only:
    ; Just return a copy of the prefix
    mov rdi, r13
    call strdup
    mov r14, rax
    jmp .prepare_result

.concatenation_failed:
    ; Cleanup on failure
    test r14, r14
    jz .cleanup
    mov rdi, r14
    call free
    xor r14, r14
    jmp .cleanup

.prepare_result:
    mov rax, r14

.cleanup:
    ; Epilogue - restore all non-volatile registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret