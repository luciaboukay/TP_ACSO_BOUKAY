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

    // Check name length (Unix v6 max filename is 14 chars)
    size_t namelen = strlen(name);
    if (namelen > sizeof(dirEnt->d_name)) {
        return -1;
    }

    // Get the directory inode
    struct inode in;
    if (inode_iget(fs, dirinumber, &in) < 0) {
        return -1;
    }

    // Verify it's a directory
    if ((in.i_mode & IFMT) != IFDIR) {
        return -1;
    }

    // Get directory size
    int dirsize = inode_getsize(&in);
    if (dirsize <= 0) {
        return -1;
    }

    // Calculate number of blocks in directory
    int numblocks = (dirsize + DISKIMG_SECTOR_SIZE - 1) / DISKIMG_SECTOR_SIZE;

    // Read through all blocks of the directory
    for (int blknum = 0; blknum < numblocks; blknum++) {
        int blocknum = inode_indexlookup(fs, &in, blknum);
        if (blocknum < 0) {
            return -1;
        }
        if (blocknum == 0) {
            continue; // Sparse block
        }

        // Read the directory block
        char block[DISKIMG_SECTOR_SIZE];
        if (diskimg_readsector(fs->dfd, blocknum, block) != DISKIMG_SECTOR_SIZE) {
            return -1;
        }

        // Scan through all directory entries in this block
        for (size_t offset = 0; offset < DISKIMG_SECTOR_SIZE; offset += sizeof(struct direntv6)) {
            struct direntv6 *current = (struct direntv6 *)(block + offset);

            // Skip empty entries (inode number 0)
            if (current->d_inumber == 0) {
                continue;
            }

            // Compare names
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

    // Name not found
    return -1;
}