#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

run_test() {
    local test_name="$1"
    local n="$2"
    local c="$3"
    local s="$4"
    local expected="$5"
    
    ((TOTAL_TESTS++))
    
    echo -e "\n${YELLOW}Test: $test_name${NC}"
    echo "Comando: ./ring $n $c $s"
    echo "Esperado: $expected"
    
    # Ejecutar el programa sin timeout
    local output
    output=$(./ring "$n" "$c" "$s" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}FAIL: Error de ejecución (código: $exit_code)${NC}"
        echo "Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Extraer solo el número del output (para manejar mensajes verbosos)
    local result=$(echo "$output" | grep -Eo '[0-9]+$')
    
    if [ "$result" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL: Output incorrecto${NC}"
        echo "Obtenido: '$result'"
        echo "Esperado: '$expected'"
        ((TESTS_FAILED++))
        return 1
    fi
}

run_error_test() {
    local test_name="$1"
    local n="$2"
    local c="$3"
    local s="$4"
    
    ((TOTAL_TESTS++))
    
    echo -e "\n${YELLOW}Test de Error: $test_name${NC}"
    echo "Comando: ./ring $n $c $s"
    
    local output
    output=$(./ring "$n" "$c" "$s" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ] || [ -z "$output" ] || [[ "$output" == *"error"* ]] || [[ "$output" == *"Error"* ]]; then
        echo -e "${GREEN}PASS: Error manejado correctamente${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL: Debería haber producido un error${NC}"
        echo "Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi
}

if [ ! -f "./ring" ]; then
    echo -e "${RED}Error: ./ring no encontrado. Asegúrate de compilar primero con 'make'${NC}"
    exit 1
fi

print_header "TESTS BÁSICOS"
run_test "3 procesos, valor inicial 0, inicia proceso 1" 3 0 1 "3"
run_test "3 procesos, valor inicial 5, inicia proceso 1" 3 5 1 "8"
run_test "4 procesos, valor inicial 10, inicia proceso 1" 4 10 1 "14"

print_header "TESTS CON DIFERENTES PROCESOS INICIADORES"
run_test "3 procesos, valor 0, inicia proceso 2" 3 0 2 "3"
run_test "3 procesos, valor 0, inicia proceso 3" 3 0 3 "3"
run_test "4 procesos, valor 1, inicia proceso 2" 4 1 2 "5"
run_test "4 procesos, valor 1, inicia proceso 4" 4 1 4 "5"

print_header "TESTS CON VALORES ESPECIALES"
run_test "Valor inicial cero" 5 0 1 "5"
run_test "Valor grande" 3 1000 1 "1003"

print_header "TESTS CON DIFERENTES TAMAÑOS DE ANILLO"
run_test "Anillo mínimo (3 procesos)" 3 1 1 "4"
run_test "Anillo de 5 procesos" 5 2 1 "7"
run_test "Anillo de 7 procesos" 7 0 1 "7"
run_test "Anillo grande (10 procesos)" 10 5 1 "15"

print_header "TESTS DE CASOS EDGE"
run_error_test "Muy pocos argumentos (solo n)" 3
run_error_test "Argumentos inválidos (n=0)" 0 5 1
run_error_test "Argumentos inválidos (n=1)" 1 5 1
run_error_test "Argumentos inválidos (n=2)" 2 5 1
run_error_test "Proceso iniciador inválido (s=0)" 3 5 0
run_error_test "Proceso iniciador mayor que n" 3 5 5

print_header "TESTS DE CONSISTENCIA"
consistent=true
for n in 3 4 5; do
    for c in 0 1 10; do
        for s in $(seq 1 $n); do
            expected=$((c + n))
            output=$(./ring "$n" "$c" "$s" 2>/dev/null)
            result=$(echo "$output" | grep -Eo '[0-9]+$')
            if [ "$result" != "$expected" ]; then
                echo -e "${RED}Inconsistencia encontrada: ring $n $c $s -> '$result', esperado '$expected'${NC}"
                consistent=false
            fi
        done
    done
done

if $consistent; then
    echo -e "${GREEN}Consistencia verificada: ✓${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}Falla de consistencia detectada${NC}"
    ((TESTS_FAILED++))
fi
((TOTAL_TESTS++))

print_header "RESULTADOS FINALES"
echo -e "Tests ejecutados: $TOTAL_TESTS"
echo -e "${GREEN}Tests pasados: $TESTS_PASSED${NC}"
echo -e "${RED}Tests fallidos: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ¡Todos los tests pasaron! Tu implementación parece correcta.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Algunos tests fallaron. Revisa tu implementación.${NC}"
    exit 1
fi