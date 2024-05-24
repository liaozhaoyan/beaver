#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include "entry.h"

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);
    if (argc >= 2) {
        start_beaver(argv[1]);
    } else {
        start_beaver("config.yaml");
    }
    return 0;
}
