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

    ; Initialize return value to NULL
    xor r14, r14

    ; Save parameters
    mov rbx, rdi       ; list
    mov r12b, sil      ; type (store as byte)
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
    test r15, r15
    jz .apply_prefix

.node_loop:
    ; Check type match
    mov al, byte [r15+16]  ; current->type
    cmp al, r12b
    jne .next_node

    ; Get current node's hash
    mov rsi, [r15+24]   ; current->hash
    test rsi, rsi
    jz .next_node

    ; Verify we have an accumulator
    test r14, r14
    jz .next_node

    ; Concatenate strings
    mov rdi, r14        ; current accumulator
    call str_concat
    test rax, rax
    jz .concat_fail

    ; Replace old string with new one
    mov rdi, r14
    mov r14, rax
    call free

.next_node:
    ; Move to next node
    mov r15, [r15]      ; current = current->next
    test r15, r15
    jnz .node_loop

.apply_prefix:
    ; Check if we need to add prefix
    test r13, r13
    jz .return_result

    ; Verify we have something to prepend to
    test r14, r14
    jz .create_prefix_copy

    ; Concatenate prefix with accumulated string
    mov rdi, r13        ; prefix
    mov rsi, r14        ; accumulated string
    call str_concat
    test rax, rax
    jz .concat_fail

    ; Replace accumulated string
    mov rdi, r14
    mov r14, rax
    call free
    jmp .return_result

.create_prefix_copy:
    ; Special case: no matches but has prefix - return copy of prefix
    mov rdi, r13
    call strdup         ; Ensure you have strdup implemented
    mov r14, rax
    jmp .return_result

.concat_fail:
    ; Cleanup on failure
    test r14, r14
    jz .return_null
    mov rdi, r14
    call free

.return_null:
    xor r14, r14

.return_result:
    mov rax, r14

    ; Epilogue
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret