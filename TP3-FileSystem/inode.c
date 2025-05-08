#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "inode.h"
#include "diskimg.h"


/**
 * TODO
 */
int inode_iget(struct unixfilesystem *fs, int inumber, struct inode *inp) {
    // Validar los inputs
    if (fs == NULL || inp == NULL || inumber <= 0) {
        return -1;
    }
    
    // Calcular el número de inodos por bloque
    int inodesPerBlock = DISKIMG_SECTOR_SIZE / sizeof(struct inode);

    // Chequear si el número de inodo es válido
    int numInodes = fs->superblock.s_isize * inodesPerBlock;
    if (inumber >= numInodes) {
        return -1;
    }

    // Calcular el número de bloque y el desplazamiento del inodo
    int blockNum = INODE_START_SECTOR + (inumber - 1) / inodesPerBlock;
    int offset = (inumber - 1) % inodesPerBlock;

    // Leer el bloque del disco que contiene el inodo
    char buffer[DISKIMG_SECTOR_SIZE];
    if (diskimg_readsector(fs->dfd, blockNum, buffer) == -1) {
        return -1;
    }

    // Copiar el inodo del bloque leído a la estructura inp
    struct inode *inodeBlock = (struct inode *)buffer;
    *inp = inodeBlock[offset];

    return 0;
}

/**
 * TODO
 */
int inode_indexlookup(struct unixfilesystem *fs, struct inode *inp, int blockNum) {  
    // Validar los inputs
    if (fs == NULL || inp == NULL || blockNum < 0) {
        return -1;
    }

    // Verificar si es un archivo grande
    int largeFile = (inp->i_mode & ILARG);
    
    if (!largeFile) {
        // Archivos chicos
        if (blockNum < 8) {
            return inp->i_addr[blockNum];
        } else {
            // Numero de bloque fuera de rango para archivos chicos
            return 0;
        }
    } else {
        // Archivos grandes
        // Punteros de indireccion simple
        if (blockNum < 7 * 256) {
            // Calcular el índice del bloque indirecto y el índice de entrada en ese bloque
            int indirectBlockIndex = blockNum / 256;
            int indirectEntryIndex = blockNum % 256;
            
            // Chequear si el bloque indirecto es válido
            if (inp->i_addr[indirectBlockIndex] == 0) {
                return 0;
            }
            
            // Leer el bloque indirecto (son 256 punteros de bloque)
            uint16_t indirectBlock[256];
            if (diskimg_readsector(fs->dfd, inp->i_addr[indirectBlockIndex], indirectBlock) == -1) {
                return -1;
            }
            
            // Devolver el número de bloque del bloque indirecto
            return indirectBlock[indirectEntryIndex];
        } 
        // Punteros de doble indireccion
        else if (blockNum < 7 * 256 + 256 * 256) {
            // Calcular el índice del bloque doblemente indirecto y el índice de entrada en ese bloque indirecto
            int doubleIndirectEntry = (blockNum - 7 * 256) / 256;
            int indirectEntryIndex = (blockNum - 7 * 256) % 256;
            
            // Chequear si el puntero de bloque doblemente indirecto es válido
            if (inp->i_addr[7] == 0) {
                return 0;
            }
            
            // Leer el bloque doblemente indirecto (son 256 punteros de bloque indirecto)
            uint16_t doubleIndirectBlock[256];
            if (diskimg_readsector(fs->dfd, inp->i_addr[7], doubleIndirectBlock) == -1) {
                return -1;
            }
            
            // Chequear si el puntero de bloque indirecto es válido
            if (doubleIndirectBlock[doubleIndirectEntry] == 0) {
                return 0;
            }
            
            // Leer el bloque indirecto (son 256 punteros de bloque)
            uint16_t indirectBlock[256];
            if (diskimg_readsector(fs->dfd, doubleIndirectBlock[doubleIndirectEntry], indirectBlock) == -1) {
                return -1;
            }
            
            // Devolver el número de bloque del bloque indirecto
            return indirectBlock[indirectEntryIndex];
        } else {
            // Número de bloque fuera de rango para archivos grandes
            return 0;
        }
    }
}

int inode_getsize(struct inode *inp) {
  return ((inp->i_size0 << 16) | inp->i_size1); 
}