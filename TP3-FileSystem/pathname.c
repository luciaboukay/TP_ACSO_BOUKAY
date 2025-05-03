
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
    if (fs == NULL || pathname == NULL) {
        return -1;
    }

    // Handle root directory case
    if (strcmp(pathname, "/") == 0) {
        return ROOT_INUMBER;
    }

    // Verify it's an absolute path
    if (pathname[0] != '/') {
        return -1;
    }

    // Start from root directory
    int current_inumber = ROOT_INUMBER;
    char component[14+1]; // Max 14 chars + null terminator
    const char *start = pathname + 1; // Skip leading '/'
    
    while (*start != '\0') {
        // Extract next path component
        const char *end = start;
        while (*end != '/' && *end != '\0') {
            end++;
        }

        size_t length = end - start;
        if (length == 0) {
            return -1; // Empty component (e.g., "foo//bar")
        }
        if (length > 14) {
            return -1; // Component too long
        }

        // Copy component (null-terminated)
        strncpy(component, start, length);
        component[length] = '\0';

        // Look up component in current directory
        struct direntv6 dirEnt;
        if (directory_findname(fs, component, current_inumber, &dirEnt) != 0) {
            return -1; // Component not found
        }

        current_inumber = dirEnt.d_inumber;
        
        // Move to next component
        start = (*end == '/') ? end + 1 : end;
    }

    return current_inumber;
}
