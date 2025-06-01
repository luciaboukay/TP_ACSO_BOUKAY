#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

#define MAX_COMMANDS 200
#define MAX_ARGS 64

char* delete_whitespace(char* str) {
    if (!str) return NULL;

    // Eliminar los espacios al principio
    while (*str == ' ' || *str == '\t') str++;

    // Ver si la cadena está vacía
    if (*str == '\0') return str;

    // Eliminar los espacios al final
    char* end = str + strlen(str) - 1;
    while (end > str && (*end == ' ' || *end == '\t')) end--;

    // Agregar el carácter nulo al final
    *(end + 1) = '\0';

    return str;
}

void free_args(char** args) {
    if (!args) return;

    // Liberar cada argumento
    for (int i = 0; args[i] != NULL; i++) {
        free(args[i]);
    }

    // Liberar el arreglo de argumentos
    free(args);
}

char** parse_command(char* command) {
    if (!command) return NULL;

    // Memoria para el arreglo de argumentos
    char** args = malloc((MAX_ARGS + 1) * sizeof(char*));

    if (args == NULL) {
        fprintf(stderr, "malloc failed\n");
        exit(EXIT_FAILURE);
    }

    int position = 0; // Posición actual en el arreglo de argumentos
    int i = 0;        // Índice para iterar el comando
    int len = strlen(command); // Longitud del comando

    // Iterar sobre el comando
    while (i < len && position < MAX_ARGS) {
        // Saltar espacios al inicio de cada argumento
        while (i < len && (command[i] == ' ' || command[i] == '\t')) {
            i++;
        }

        // Ver si se llegó al final de la cadena
        if (i >= len) break;

        // Memoria para el argumento actual
        char* arg = malloc(256);

        if (!arg) {
            fprintf(stderr, "malloc failed\n");
            exit(EXIT_FAILURE);
        }

        int arg_pos = 0; // Posición actual en el argumento

        // Manejar cadenas entre comillas dobles o simples
        if (command[i] == '"' || command[i] == '\'') {
            char quote = command[i]; // Guardar el tipo de comilla
            i++; // Saltar la comilla inicial
            while (i < len && command[i] != quote) {
                arg[arg_pos++] = command[i++];
            }
            if (i < len) i++; // Saltar la comilla final
        } else {
            // Cadena sin comillas
            while (i < len && command[i] != ' ' && command[i] != '\t') {
                arg[arg_pos++] = command[i++];
            }
        }

        // Agregar el carácter nulo
        arg[arg_pos] = '\0';

        // Agregar el argumento al arreglo de argumentos
        args[position++] = arg;
    }

    // Verificar si se excedió el límite de argumentos
    while (position >= MAX_ARGS && i < len) {
        if (command[i] != ' ' && command[i] != '\t') {
            fprintf(stderr, "Too many arguments in command\n");
            free_args(args);
            return NULL;
        }
        i++;
    }

    // Terminar el arreglo de argumentos con NULL
    args[position] = NULL;

    return args;
}

int main() {
    char command[256];
    char *commands[MAX_COMMANDS];
    int command_count = 0;

    while (1) {
        command_count = 0;

        // Leer el input
        if (!fgets(command, sizeof(command), stdin)){
            fprintf(stderr, "Error reading command\n");
            exit(EXIT_FAILURE);
        }

        // Eliminar el salto de línea al final
        command[strcspn(command, "\n")] = '\0';

        // Ver si el comando está vacío
        if (strlen(command) == 0) {
            continue;
        }

        // Validar la sintaxis de los pipes
        if (strstr(command, "||") || command[0] == '|' || command[strlen(command) - 1] == '|') {
            fprintf(stderr, "Syntax error: Invalid pipe usage\n");
            continue;
        }

        // Separar los comandos por pipes
        char *token = strtok(command, "|");
        while (token != NULL && command_count < MAX_COMMANDS) {
            char* trimmed = delete_whitespace(token);
            // Verificar si el comando no está vacío
            if (strlen(trimmed) > 0) {
                commands[command_count++] = trimmed;
            }
            token = strtok(NULL, "|");
        }

        // Verificar si se proporcionó al menos un comando
        if (command_count == 0) {
            fprintf(stderr, "Error: No command provided\n");
            continue;
        }

        // Verificar si el comando es exit
        if (command_count == 1 && strcmp(commands[0], "exit") == 0) {
            exit(EXIT_SUCCESS);
        }

        // Crear los pipes 
        int pipes[command_count - 1][2];
        for (int i = 0; i < command_count - 1; i++) {
            if (pipe(pipes[i]) == -1) {
                fprintf(stderr, "Error creating pipe %d\n", i);
                exit(EXIT_FAILURE);
            }
        }

        // Hacer fork para cada comando
        for (int i = 0; i < command_count; i++) {
            pid_t pid = fork();
            if (pid == -1) {
                fprintf(stderr, "Fork failed\n");
                exit(EXIT_FAILURE);
            } else if (pid == 0) {
                // Proceso hijo

                // Si no es el primer comando, redirigir stdin al pipe anterior
                if (i > 0) {
                    if (dup2(pipes[i - 1][0], STDIN_FILENO) == -1) {
                        fprintf(stderr, "dup2 stdin failed\n");
                        exit(EXIT_FAILURE);
                    }
                }

                // Si no es el último comando, redirigir stdout al pipe siguiente
                if (i < command_count - 1) {
                    if (dup2(pipes[i][1], STDOUT_FILENO) == -1) {
                        fprintf(stderr, "dup2 stdout failed\n");
                        exit(EXIT_FAILURE);
                    }
                }

                // Cerrar los pipes en el proceso hijo
                for (int j = 0; j < command_count - 1; j++) {
                    close(pipes[j][0]);
                    close(pipes[j][1]);
                }

                // Parsear el comando
                char** args = parse_command(commands[i]);
                if (args == NULL || args[0] == NULL) {
                    // Si no se pudo parsear el comando, liberar memoria y salir
                    free_args(args);
                    fprintf(stderr, "Failed to parse command: %s\n", commands[i]);
                    exit(EXIT_FAILURE);
                }

                // Ejecutar el comando
                execvp(args[0], args);
                
                // Solo llega aca si execvp falla
                fprintf(stderr, "execvp failed for command: %s\n", commands[i]);
                free_args(args);
                exit(EXIT_FAILURE);
            }
        }

        // Cerrar los extremos de los pipes en el padre
        for (int i = 0; i < command_count - 1; i++) {
            close(pipes[i][0]);
            close(pipes[i][1]);
        }

        // Esperar a que terminen todos los procesos hijos
        for (int i = 0; i < command_count; i++) {
            wait(NULL);
        }
    }

    return 0;
}
