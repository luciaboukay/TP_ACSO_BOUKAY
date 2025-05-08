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
    struct inode inode;

    // Obtener el inode
    if (inode_iget(fs, inumber, &inode) == -1) {
        return -1;
    }

    // Obtener el número de bloque físico correspondiente
    int sector = inode_indexlookup(fs, &inode, blockNum);
    if (sector <= 0) {
        return -1;
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

