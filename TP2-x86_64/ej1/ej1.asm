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
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    
    ; Llamar a malloc para crear la lista
    mov rdi, 16       ; sizeof(string_proc_list) = 16 bytes (2 punteros de 8 bytes)
    call malloc
    
    ; Verificar si malloc falló
    test rax, rax
    jz .end
    
    ; Inicializar la lista
    mov qword [rax], NULL    ; list->first = NULL
    mov qword [rax+8], NULL  ; list->last = NULL
    jmp .end
    
.end:
    ; Epílogo de función
    pop rbp
    ret

string_proc_node_create_asm:
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    push rbx        
    push r12        
    
    ; Verificar si hash es NULL
    test rsi, rsi
    jz .return_null

    ; Guardar parámetros
    mov bl, dil      ; type
    mov r12, rsi     ; hash
    
    ; Llamar a malloc para crear el nodo
    mov rdi, 32      ; sizeof(string_proc_node)
    call malloc
    
    ; Verificar si malloc falló
    test rax, rax
    jz .return_null
    
    ; Inicializar el nodo
    mov qword [rax], NULL     ; node->next = NULL
    mov qword [rax+8], NULL   ; node->previous = NULL
    mov byte [rax+16], bl     ; node->type = type
    mov qword [rax+24], r12   ; node->hash = hash
    
    jmp .end
    
.return_null:
    xor rax, rax      ; Devolver NULL
    
.end:
    ; Epílogo de función
    pop r12
    pop rbx
    pop rbp
    ret

string_proc_list_add_node_asm:
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    
    ; Guardar parámetros
    mov r12, rdi       ; list
    mov r13, rdx       ; hash
    mov r14, rsi       ; type
    
    ; Verificar si list es NULL
    test r12, r12
    jz .return_null
    
    ; Llamar a string_proc_node_create_asm(type, hash)
    mov rdi, rsi       ; type
    mov rsi, rdx       ; hash
    call string_proc_node_create_asm
    
    ; Verificar si la creación del nodo falló
    test rax, rax
    jz .return_null
    
    ; Guardar el puntero al nodo creado
    mov r15, rax       ; node
    
    ; Verificar si la lista está vacía (list->first == NULL)
    cmp qword [r12], NULL
    jne .list_not_empty
    
    ; Si la lista está vacía
    mov [r12], r15          ; list->first = node
    mov [r12+8], r15        ; list->last = node
    jmp .end
    
.list_not_empty:
    ; Si la lista no está vacía
    mov rax, [r12+8]        ; rax = list->last
    mov [rax], r15          ; list->last->next = node
    mov [r15+8], rax        ; node->previous = list->last
    mov [r12+8], r15        ; list->last = node
    jmp .end
    
.return_null:
    xor rax, rax            ; Return FALSE
    
.end:
    ; Epílogo de función
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

string_proc_list_concat_asm:
    ; Prólogo de función
    push rbp
    mov rbp, rsp
    push rbx           ; Preservar registros callee-saved
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8         ; Alinear la pila a 16 bytes 
    
    ; Guardar parámetros
    mov rbx, rdi       ; list
    movzx r12d, sil    ; type (extendido a 32 bits)
    mov r13, rdx       ; hash
    
    ; Verificar si list es NULL
    test rbx, rbx
    jnz .list_valid

    ; Si list es NULL, devolver NULL
    xor eax, eax
    jmp .end

.list_valid:

    ; Asignar memoria para new_hash (1 byte para el string vacío con '\0')
    mov rdi, 1
    call malloc
    
    ; Verificar si malloc falló
    test rax, rax
    jnz .malloc_success
    
    ; Si malloc falló, devolver NULL
    xor eax, eax
    jmp .end

.malloc_success:
    ; Inicializar new_hash como string vacío
    mov byte [rax], 0     ; new_hash[0] = '\0'
    mov r14, rax          ; r14 = new_hash
    
    ; Inicializar current_node = list->first
    mov r15, [rbx]        ; r15 = list->first (current_node)
    
.loop_start:
    ; Verificar si current_node es NULL
    test r15, r15
    jz .loop_end
    
    ; Verificar si el tipo coincide (current_node->type == type)
    movzx eax, byte [r15+16]
    cmp al, r12b
    jne .next_node
    
    ; Llamar a str_concat(new_hash, current_node->hash)
    mov rdi, r14         ; primer parámetro: new_hash
    mov rsi, [r15+24]         ; segundo parámetro: current_node->hash
    call str_concat
    
    ; Liberar el antiguo new_hash
    mov rdi, r14
    mov r14, rax         ; guardar el nuevo puntero
    call free
    
.next_node:
    ; Avanzar al siguiente nodo: current_node = current_node->next
    mov r15, [r15]
    jmp .loop_start
    
.loop_end:
    ; Verificar si hash es NULL
    test r13, r13
    jz .return_result
    
    ; Llamar a str_concat(hash, new_hash)
    mov rdi, r13         ; primer parámetro: hash
    mov rsi, r14         ; segundo parámetro: new_hash
    call str_concat

    ; Liberar el antiguo new_hash
    mov rdi, r14
    mov r14, rax         ; guardar el nuevo puntero
    call free
    jmp .return_result
    
.return_null:
    xor eax, eax        ; Devolver NULL
    jmp .end

.return_result:
    ; Preparar el valor de retorno
    mov rax, r14
    
.end:
    ; Epílogo de función
    add rsp, 8          ; Restaurar espacio reservado
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

