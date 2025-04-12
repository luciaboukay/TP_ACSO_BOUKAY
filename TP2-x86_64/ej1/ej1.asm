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
    ; PRÓLOGO DE LA FUNCIÓN
    PUSH RBP
    MOV RBP, RSP
    PUSH RBX             
    PUSH R12
    PUSH R13
    PUSH R14
    PUSH R15
    SUB RSP, 8 
    
    ; GUARDAR LOS PARÁMETROS EN REGISTROS NO VOLÁTILES
    MOV R12, RDI            ; R12 = LIST
    MOV R13, RSI            ; R13 = TYPE
    MOV R14, RDX            ; R14 = HASH
    
    ; OBTENER EL PRIMER NODO DE LA LISTA
    MOV R15, [R12]          ; R15 = LIST->FIRST
    
    ; INICIALIZAR EL NUEVO HASH COMO STRING VACÍO
    MOV RDI, 1              ; TAMAÑO: 1 BYTE PARA '\0'
    CALL malloc
    TEST RAX, RAX           ; VERIFICAR SI malloc FALLÓ
    JZ .ERROR_SALIDA
    
    MOV BYTE [RAX], 0       ; NEW_HASH[0] = '\0'
    MOV RBX, RAX            ; RBX = NEW_HASH (LO GUARDAMOS PARA USARLO DESPUÉS)
    
.BUCLE_NODOS:
    TEST R15, R15           ; IF(CURRENT_NODE == NULL)
    JZ .CONCATENAR_HASH_FINAL   ; SI ES NULL, SALIMOS DEL BUCLE
    
    ; COMPROBAR TIPO DEL NODO
    MOVZX EAX, BYTE [R15 + 16]  ; CURRENT_NODE->TYPE (OFFSET 16 EN LA ESTRUCTURA)
    CMP AL, R13B            ; COMPARAR CON EL TIPO BUSCADO
    JNE .SIGUIENTE_NODO     ; SI NO COINCIDE, PASAMOS AL SIGUIENTE NODO
    
    ; EL TIPO COINCIDE, CONCATENAR HASH
    MOV RDI, RBX            ; PRIMER PARÁMETRO: NEW_HASH
    MOV RSI, [R15 + 24]     ; SEGUNDO PARÁMETRO: CURRENT_NODE->HASH (OFFSET 24)
    CALL str_concat         ; LLAMAR A str_concat
    
    MOV RDI, RBX            ; PREPARAR PARA LIBERAR EL VIEJO HASH
    MOV RBX, RAX            ; ACTUALIZAR PUNTERO AL NUEVO HASH
    CALL free               ; LIBERAR EL VIEJO HASH
    
.SIGUIENTE_NODO:
    MOV R15, [R15]          ; CURRENT_NODE = CURRENT_NODE->NEXT (OFFSET 0)
    JMP .BUCLE_NODOS        ; VOLVER A COMPROBAR

.CONCATENAR_HASH_FINAL:
    ; VERIFICAR SI HASH ES NULL (DIFERENTE DE LA VERSIÓN ORIGINAL)
    TEST R14, R14
    JZ .FINALIZAR           ; Si HASH es NULL, saltamos directamente a retornar

    ; CONCATENAR EL HASH FINAL PASADO POR PARÁMETRO
    MOV RDI, R14            ; PRIMER PARÁMETRO: HASH (PARÁMETRO)
    MOV RSI, RBX            ; SEGUNDO PARÁMETRO: NEW_HASH
    CALL str_concat         ; LLAMAR A str_concat
    
    MOV RDI, RBX            ; PREPARAR PARA LIBERAR EL VIEJO HASH
    MOV RBX, RAX            ; GUARDAR RESULTADO FINAL
    CALL free               ; LIBERAR EL VIEJO HASH

.FINALIZAR:
    ;CHEQUEAR NO SACO LOS REGISTROS
    MOV RAX, RBX            ; RETORNAR EL NUEVO HASH

.ERROR_SALIDA:
    ; EPÍLOGO DE LA FUNCIÓN
    ADD RSP, 8 
    POP R15
    POP R14
    POP R13
    POP R12
    POP RBX
    LEAVE
    RET