#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <fake-name> <command> [args...]\n", argv[0]);
        return 1;
    }
    char *command = argv[2];
    char **new_argv = malloc(sizeof(char *) * (argc - 1));
    new_argv[0] = argv[1];                 // the fake argv[0]
    for (int i = 3; i < argc; i++) {
        new_argv[i - 2] = argv[i];         // real args, shifted down
        printf("%d\n", i);
    }
    new_argv[argc - 2] = NULL;

    execvp(command, new_argv);
    perror("execvp");                      // only reached on failure
    return 127;
}
