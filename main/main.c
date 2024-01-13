#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include "entry.h"

int main(int argc, char *argv[]) {
    signal(SIGPIPE, SIG_IGN);

    start_beaver("config.yaml");
    return 0;
}
