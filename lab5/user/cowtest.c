#include <stdio.h>
#include <ulib.h>
#include <string.h>

int main(void) {
    int pid;
    volatile int value = 100;
    char *str = "Parent string";
    
    cprintf("COW Test: Parent before fork, value = %d\n", value);

    pid = fork();

    if (pid == 0) {
        // Child
        cprintf("COW Test: Child before write, value = %d\n", value);
        if (value != 100) {
             cprintf("COW Test: Child read wrong value!\n");
             exit(-1);
        }
        
        cprintf("COW Test: Child writing to value...\n");
        value = 200; // This should trigger COW
        cprintf("COW Test: Child after write, value = %d\n", value);
        
        if (value != 200) {
             cprintf("COW Test: Child write failed!\n");
             exit(-1);
        }
        cprintf("COW Test: Child exiting.\n");
        exit(0);
    } else {
        // Parent
        if (pid < 0) {
            cprintf("COW Test: Fork failed.\n");
            exit(-1);
        }
        
        cprintf("COW Test: Parent waiting for child...\n");
        if (wait() != 0) {
             cprintf("COW Test: Wait failed.\n");
             exit(-1);
        }
        
        cprintf("COW Test: Parent after child exit, value = %d\n", value);
        if (value != 100) {
             cprintf("COW Test: Parent value changed! COW failed isolation.\n");
             exit(-1);
        }
        cprintf("COW Test: Parent value correct. COW Test Passed.\n");
    }
    return 0;
}
