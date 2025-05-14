#include "directory.h"
#include "inode.h"
#include "diskimg.h"
#include "file.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

/**
 * TODO
 */
int directory_findname(struct unixfilesystem *fs, const char *name,
                      int dirinumber, struct direntv6 *dirEnt) {

    // Validar los inputs
    if (fs == NULL || name == NULL || dirEnt == NULL) {
        return -1;
    }

    // Chequear el largo del nombre
    size_t namelen = strlen(name);
    if (namelen > sizeof(dirEnt->d_name)) {
        return -1;
    }

    // Obtener el inodo del directorio
    struct inode inode;
    if (inode_iget(fs, dirinumber, &inode) < 0) {
        return -1;
    }

    // Verificar si el inodo está asignado
    if ((inode.i_mode & IALLOC) == 0) {
        return -1;
    }

    // Verificar si el inodo es un directorio
    if ((inode.i_mode & IFMT) != IFDIR) {
        return -1;
    }

    // Obtener el tamaño del directorio
    int dirsize = inode_getsize(&inode);
    if (dirsize <= 0) {
        return -1;
    }

    // Calcular el número de bloques del directorio
    int numblocks = (dirsize + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;

    // Leer los bloques del directorio
    for (int blknum = 0; blknum < numblocks; blknum++) {
        // Leer el bloque del disco
        char block[DISKIMG_SECTOR_SIZE];
        if (file_getblock(fs, dirinumber, blknum, block) == -1) {
            return -1;
        }

        // Ver las entradas del directorio
        for (size_t offset = 0; offset < DISKIMG_SECTOR_SIZE; offset += sizeof(struct direntv6)) {
            struct direntv6 *current = (struct direntv6 *)(block + offset);

            // Saltear entradas vacías
            if (current->d_inumber == 0) {
                continue;
            }

            // Comparar el nombre
            size_t current_namelen = strnlen(current->d_name, sizeof(current->d_name));
            if (current_namelen == sizeof(current->d_name)) {
                if (namelen == sizeof(current->d_name) && 
                    strncmp(current->d_name, name, sizeof(current->d_name)) == 0) {
                    *dirEnt = *current;
                    return 0;
                }
            } else {
                if (namelen == current_namelen && 
                    strcmp(current->d_name, name) == 0) {
                    *dirEnt = *current;
                    return 0;
                }
            }
        }
    }

    // Nombre no encontrado
    return -1;
}