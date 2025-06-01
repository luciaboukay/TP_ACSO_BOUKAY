CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -g
TARGET = ring
TEST_SCRIPT = test_ring.sh
UNIT_TESTS = ring_tests
UNIT_TEST_SRC = ring_tests.c

# Objetivos principales
.PHONY: all test test-unit test-bash clean help

all: $(TARGET)

# Compilar ring (asumiendo que tienes ring.c)
$(TARGET): ring.c
	$(CC) $(CFLAGS) -o $(TARGET) ring.c

# Compilar unit tests en C
$(UNIT_TESTS): $(UNIT_TEST_SRC)
	$(CC) $(CFLAGS) -o $(UNIT_TESTS) $(UNIT_TEST_SRC)

# Hacer el script de bash ejecutable
$(TEST_SCRIPT): 
	chmod +x $(TEST_SCRIPT)

# Ejecutar todos los tests
test: test-bash test-unit

# Ejecutar tests de bash
test-bash: $(TARGET) $(TEST_SCRIPT)
	@echo "Ejecutando tests de bash..."
	./$(TEST_SCRIPT)

# Ejecutar unit tests en C
test-unit: $(TARGET) $(UNIT_TESTS)
	@echo "Ejecutando unit tests en C..."
	./$(UNIT_TESTS)

# Test rápido (solo casos básicos)
test-quick: $(TARGET)
	@echo "Ejecutando tests rápidos..."
	@echo "Test 1: ring 3 0 1 (esperado: 3)"
	@timeout 5s ./ring 3 0 1 || echo "FAIL"
	@echo "Test 2: ring 4 5 1 (esperado: 9)"
	@timeout 5s ./ring 4 5 1 || echo "FAIL"
	@echo "Test 3: ring 3 -2 2 (esperado: 1)"
	@timeout 5s ./ring 3 -2 2 || echo "FAIL"

# Verificar memory leaks con valgrind (si está disponible)
test-memory: $(TARGET)
	@if command -v valgrind >/dev/null 2>&1; then \
		echo "Verificando memory leaks..."; \
		valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes \
		         --verbose --log-file=valgrind.log ./ring 4 1 1; \
		echo "Revisa valgrind.log para detalles"; \
	else \
		echo "Valgrind no está disponible, saltando test de memoria"; \
	fi

# Test de performance
test-performance: $(TARGET)
	@echo "Ejecutando tests de performance..."
	@echo "Test con anillo grande (20 procesos):"
	@time timeout 10s ./ring 20 0 1
	@echo "Test con valor grande:"
	@time timeout 10s ./ring 5 999999 1

# Debug: ejecutar con gdb
debug: $(TARGET)
	gdb --args ./ring 3 0 1

# Limpiar archivos generados
clean:
	rm -f $(TARGET) $(UNIT_TESTS) valgrind.log
	rm -f core.*

# Mostrar ayuda
help:
	@echo "Makefile para tests de ring.c"
	@echo ""
	@echo "Objetivos disponibles:"
	@echo "  all           - Compilar ring"
	@echo "  test          - Ejecutar todos los tests"
	@echo "  test-bash     - Ejecutar tests de bash"
	@echo "  test-unit     - Ejecutar unit tests en C"
	@echo "  test-quick    - Ejecutar solo tests básicos"
	@echo "  test-memory   - Verificar memory leaks con valgrind"
	@echo "  test-performance - Tests de rendimiento"
	@echo "  debug         - Ejecutar con gdb"
	@echo "  clean         - Limpiar archivos generados"
	@echo "  help          - Mostrar esta ayuda"
	@echo ""
	@echo "Ejemplos:"
	@echo "  make test           - Ejecutar todos los tests"
	@echo "  make test-quick     - Solo tests básicos"
	@echo "  make clean test     - Limpiar y ejecutar tests"
