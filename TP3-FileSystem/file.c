#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "file.h"
#include "inode.h"
#include "diskimg.h"

/**
 * TODO
 */
int file_getblock(struct unixfilesystem *fs, int inumber, int blockNum, void *buf) {
    // Validar los inputs
    if (fs == NULL || buf == NULL || inumber <= 0 || blockNum < 0) {
        return -1;
    }

    struct inode inode;

    // Obtener el inode
    if (inode_iget(fs, inumber, &inode) == -1) {
        return -1;
    }

    // Verificar si el inodo esta asignado
    if ((inode.i_mode & IALLOC) == 0) {
        return -1;
    }

    // Obtener el número de bloque físico correspondiente
    int sector = inode_indexlookup(fs, &inode, blockNum);
    if (sector == 1) {
        // Bloque fuera de rango
        return -1;
    } else if (sector == 0) {
        // Bloque no asignado
        return 0; 
    }

    // Leer el bloque del disco
    if (diskimg_readsector(fs->dfd, sector, buf) == -1) {
        return -1;
    }

    // Calcular tamaño del archivo y cuántos bytes son válidos en este bloque
    int filesize = inode_getsize(&inode);
    int start = blockNum * DISKIMG_SECTOR_SIZE;

    if (filesize > start + DISKIMG_SECTOR_SIZE) {
        // Bloque completo
        return DISKIMG_SECTOR_SIZE;
    } else if (filesize > start) {
        // Bloque parcial
        return filesize - start;
    } else {
        // Bloque fuera de rango del archivo
        return 0;
    }
}

