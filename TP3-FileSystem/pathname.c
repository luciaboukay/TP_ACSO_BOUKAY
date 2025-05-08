
#include "pathname.h"
#include "directory.h"
#include "inode.h"
#include "diskimg.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

/**
 * TODO
 */
int pathname_lookup(struct unixfilesystem *fs, const char *pathname) {
    // Validar los inputs
    if (fs == NULL || pathname == NULL) {
        return -1;
    }

    // Verificar que el pathname comience con '/'
    if (pathname[0] != '/') {
        return -1;
    }

    // Caso del directorio raíz
    if (strcmp(pathname, "/") == 0) {
        return ROOT_INUMBER;
    }

    // Empezar la búsqueda desde el directorio raíz
    int current_inumber = ROOT_INUMBER;
    char component[14+1]; 
    const char *start = pathname + 1;
    
    while (*start != '\0') {
        // Encontrar el siguiente separador '/'
        const char *end = start;
        while (*end != '/' && *end != '\0') {
            end++;
        }

        size_t length = end - start;
        if (length == 0) {
            return -1; // Componente vacío
        }
        if (length > 14) {
            return -1; // Componente mas largo que 14 caracteres
        }

        // Copiar el componente
        strncpy(component, start, length);
        component[length] = '\0';

        // Buscar el componente en el directorio actual
        struct direntv6 dirEnt;
        if (directory_findname(fs, component, current_inumber, &dirEnt) != 0) {
            return -1;
        }

        current_inumber = dirEnt.d_inumber;
        
        // Mover al siguiente componente
        if (*end == '/'){
            start = end + 1;
        } else {
            start = end;
        }
    }

    return current_inumber;
}
