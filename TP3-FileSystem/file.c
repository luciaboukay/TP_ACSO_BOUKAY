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
    struct inode in;

    // Paso 1: obtener el inode
    if (inode_iget(fs, inumber, &in) == -1) {
        return -1;
    }

    // Paso 2: obtener el número de bloque físico correspondiente
    int sector = inode_indexlookup(fs, &in, blockNum);
    if (sector <= 0) {
        return -1;
    }

    // Paso 3: leer el bloque del disco
    if (diskimg_readsector(fs->dfd, sector, buf) == -1) {
        return -1;
    }

    // Paso 4: calcular tamaño del archivo y cuántos bytes son válidos en este bloque
    int filesize = inode_getsize(&in);
    int start = blockNum * DISKIMG_SECTOR_SIZE;

    if (filesize > start + DISKIMG_SECTOR_SIZE) {
        return DISKIMG_SECTOR_SIZE;
    } else if (filesize > start) {
        return filesize - start;  // último bloque parcial
    } else {
        return 0;  // bloque fuera del archivo
    }
}

