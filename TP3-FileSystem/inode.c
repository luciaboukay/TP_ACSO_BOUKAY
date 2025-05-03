#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "inode.h"
#include "diskimg.h"


/**
 * TODO
 */
int inode_iget(struct unixfilesystem *fs, int inumber, struct inode *inp) {
    // Check if the filesystem is initialized
    if (fs == NULL) {
        return -1;
    }
    // Check if the inp structure is valid
    if (inp == NULL) {
        return -1;
    }
    
    // Calculate the number of inodes per block
    int inodesPerBlock = DISKIMG_SECTOR_SIZE / sizeof(struct inode);
    
    // Calculate the total number of inodes in the filesystem
    // The superblock's s_isize field specifies the size of the inode list in blocks
    int numInodes = fs->superblock.s_isize * inodesPerBlock;

    // Check if the inumber is valid (inode numbers start at 1, not 0)
    if (inumber <= 0 || inumber >= numInodes) {
        return -1;
    }

    // Calculate the block number and offset of the inode
    // Note: Inode blocks start at INODE_START_SECTOR
    int blockNum = INODE_START_SECTOR + (inumber - 1) / inodesPerBlock;
    int offset = (inumber - 1) % inodesPerBlock;

    // Read the inode block from the disk
    char buffer[DISKIMG_SECTOR_SIZE];
    if (diskimg_readsector(fs->dfd, blockNum, buffer) == -1) {
        return -1;
    }

    // Copy the inode data into the inp structure
    struct inode *inodeBlock = (struct inode *)buffer;
    *inp = inodeBlock[offset];

    return 0;
}

/**
 * TODO
 */
int inode_indexlookup(struct unixfilesystem *fs, struct inode *inp, int blockNum) {  
    // Check if the filesystem is initialized
    if (fs == NULL) {
        return -1;
    }
    // Check if the inp structure is valid
    if (inp == NULL) {
        return -1;
    }
    
    // Check if the block number is valid
    if (blockNum < 0) {
        return -1;
    }
    
    // Check if the file is using large file algorithm
    int largeFile = (inp->i_mode & ILARG);
    
    if (!largeFile) {
        // For non-large files, all 8 i_addr entries are direct blocks
        if (blockNum < 8) {
            return inp->i_addr[blockNum];
        } else {
            // Block number out of range for non-large files
            return 0; // Return 0 for sparse file blocks beyond the file's allocated blocks
        }
    } else {
        // Check if we're accessing one of the indirect blocks
        if (blockNum < 7 * 256) {
            // Calculate which indirect block and which entry in that block
            int indirectBlockIndex = blockNum / 256;
            int indirectEntryIndex = blockNum % 256;
            
            // Check if the indirect block pointer is valid
            if (inp->i_addr[indirectBlockIndex] == 0) {
                return 0; // Block doesn't exist (sparse file)
            }
            
            // Read the indirect block
            uint16_t indirectBlock[256]; // 256 block pointers in a 512-byte block
            if (diskimg_readsector(fs->dfd, inp->i_addr[indirectBlockIndex], indirectBlock) == -1) {
                return -1;
            }
            
            // Return the block number from the indirect block
            return indirectBlock[indirectEntryIndex];
        } 
        // Check if we're accessing the double indirect block
        else if (blockNum < 7 * 256 + 256 * 256) {
            // Calculate which entry in the double indirect block and which entry in that indirect block
            int doubleIndirectEntry = (blockNum - 7 * 256) / 256;
            int indirectEntryIndex = (blockNum - 7 * 256) % 256;
            
            // Check if the double indirect block pointer is valid
            if (inp->i_addr[7] == 0) {
                return 0; // Block doesn't exist (sparse file)
            }
            
            // Read the double indirect block
            uint16_t doubleIndirectBlock[256];
            if (diskimg_readsector(fs->dfd, inp->i_addr[7], doubleIndirectBlock) == -1) {
                return -1;
            }
            
            // Check if the pointer to the indirect block is valid
            if (doubleIndirectBlock[doubleIndirectEntry] == 0) {
                return 0; // Block doesn't exist (sparse file)
            }
            
            // Read the indirect block
            uint16_t indirectBlock[256];
            if (diskimg_readsector(fs->dfd, doubleIndirectBlock[doubleIndirectEntry], indirectBlock) == -1) {
                return -1;
            }
            
            // Return the block number from the indirect block
            return indirectBlock[indirectEntryIndex];
        } else {
            // Block number out of range for large files
            return 0; // Return 0 for sparse file blocks beyond the file's allocated blocks
        }
    }
}

int inode_getsize(struct inode *inp) {
  return ((inp->i_size0 << 16) | inp->i_size1); 
}
