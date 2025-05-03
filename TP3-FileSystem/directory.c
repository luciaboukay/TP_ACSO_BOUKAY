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
    // Validate inputs
    if (fs == NULL || name == NULL || dirEnt == NULL) {
        return -1;
    }

    // Check name length (Unix v6 max filename is 14 chars, including null terminator)
    if (strlen(name) > sizeof(dirEnt->d_name)) {
        return -1; // Name too long
    }

    // Get the directory inode
    struct inode in;
    if (inode_iget(fs, dirinumber, &in) < 0) {
        return -1; // Failed to get inode
    }

    // Verify it's a directory
    if ((in.i_mode & IFMT) != IFDIR) {
        return -1; // Not a directory
    }

    // Get directory size
    int dirsize = inode_getsize(&in);
    if (dirsize <= 0) {
        return -1; // Empty directory
    }

    // Calculate number of blocks in directory
    int numblocks = (dirsize + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;

    // Read through all blocks of the directory
    for (int blknum = 0; blknum < numblocks; blknum++) {
        int blocknum = inode_indexlookup(fs, &in, blknum);
        if (blocknum < 0) {
            return -1; // Block lookup failed
        }
        if (blocknum == 0) {
            continue; // Sparse block
        }

        // Read the directory block
        char block[DISKIMG_SECTOR_SIZE];
        if (diskimg_readsector(fs->dfd, blocknum, block) != DISKIMG_SECTOR_SIZE) {
            return -1; // Read failed
        }

        // Scan through all directory entries in this block
        for (int offset = 0; offset < DISKIMG_SECTOR_SIZE; offset += sizeof(struct direntv6)) {
            struct direntv6 *current = (struct direntv6 *)(block + offset);

            // Skip empty entries (inode number 0)
            if (current->d_inumber == 0) {
                continue;
            }
            
            // Check if the name matches
            int namelen = strnlen(current->d_name, sizeof(current->d_name));
            if (namelen == sizeof(current->d_name) && 
                strncmp(current->d_name, name, sizeof(current->d_name)) == 0) {
                // Full 14-character name match
                *dirEnt = *current;
                return 0;
            } else if (namelen < sizeof(current->d_name) && 
                       strcmp(current->d_name, name) == 0) {
                // Null-terminated name match
                *dirEnt = *current;
                return 0;
            }
        }
    }

    // Name not found
    return -1;
}