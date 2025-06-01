#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char **argv) {
    int start, pid, n;
    int buffer[1];

    // Validar los parametros
    if (argc != 4) {
        fprintf(stderr, "Uso: anillo <n> <c> <s>\n");
        exit(EXIT_FAILURE);
    }

    n = atoi(argv[1]);
    buffer[0] = atoi(argv[2]);
    start = atoi(argv[3]);

    if (n < 3) {
        fprintf(stderr, "Error: El numero de procesos debe ser al menos 3\n");
        exit(EXIT_FAILURE);
    }

    if (start < 1 || start > n) {
        fprintf(stderr, "Error: El proceso inicial debe estar entre 1 y %d\n", n);
        exit(EXIT_FAILURE);
    }

    printf("Se crearán %i procesos, se enviará el caracter %i desde proceso %i \n", n, buffer[0], start);

    // Crear pipes del ring
    int pipes[n][2];
    for (int i = 0; i < n; i++) {
        if (pipe(pipes[i]) == -1) {
            exit(EXIT_FAILURE);
        }
    }

    // Pipe padre a hijo inicial (enviar el valor inicial)
    int parent_to_child[2];
    if (pipe(parent_to_child) == -1) {
        exit(EXIT_FAILURE);
    }

    // Pipe hijo a padre (recibir el resultado final)
    int child_to_parent[2];
    if (pipe(child_to_parent) == -1) {
        exit(EXIT_FAILURE);
    }

    for (int i = 0; i < n; i++) {
        pid = fork();
        if (pid < 0) {
            exit(EXIT_FAILURE);
        } else if (pid == 0) {
            // Proceso hijo
            // Cerrar los pipes que no se usan
            for (int j = 0; j < n; j++) {
                if (j != i) close(pipes[j][0]);
                if (j != (i + 1) % n) close(pipes[j][1]);
            }

            close(parent_to_child[1]); // Cerrar la punta de escritura
            close(child_to_parent[0]); // Cerrar la punta de lectura

            // Chequear si es el hijo inicial
            if (i == start - 1) {
                // Recibir el mensaje del padre
                if (read(parent_to_child[0], buffer, sizeof(int)) != sizeof(int)) {
                    exit(EXIT_FAILURE);
                }
            } else {
                // Recibir el mensaje del proceso anterior
                if (read(pipes[i][0], buffer, sizeof(int)) != sizeof(int)) {
                    exit(EXIT_FAILURE);
                }
            }

            // Incrementa el valor
            buffer[0]++; 

            // Chequear si es el ultimo hijo del ring
            if (i == (start - 2 + n) % n) {
                // Enviar el resultado al padre
                if (write(child_to_parent[1], buffer, sizeof(int)) != sizeof(int)) {
                    exit(EXIT_FAILURE);
                }
            } else {
                // Enviar al siguiente proceso del anillo
                if (write(pipes[(i + 1) % n][1], buffer, sizeof(int)) != sizeof(int)) {
                    exit(EXIT_FAILURE);
                }
            }

            // Cerrar pipes
            close(pipes[i][0]);
            close(pipes[(i + 1) % n][1]);
            close(parent_to_child[0]);
            close(child_to_parent[1]);
            exit(EXIT_SUCCESS);
        }
    }

    // Proceso padre
    // Cerrar todos los pipes del ring
    for (int i = 0; i < n; i++) {
        close(pipes[i][0]);
        close(pipes[i][1]);
    }

    close(parent_to_child[0]); // Solo va a escribir
    close(child_to_parent[1]); // Solo va a leer

    // Enviar valor inicial
    if (write(parent_to_child[1], buffer, sizeof(int)) != sizeof(int)) {
        exit(EXIT_FAILURE);
    }

    close(parent_to_child[1]);

    // Leer resultado final
    if (read(child_to_parent[0], buffer, sizeof(int)) != sizeof(int)) {
        exit(EXIT_FAILURE);
    }

    close(child_to_parent[0]);

    // Mostrar resultado final
    printf("%d\n", buffer[0]);

    // Esperar a todos los hijos
    for (int i = 0; i < n; i++) {
        wait(NULL);
    }

    return 0;
}