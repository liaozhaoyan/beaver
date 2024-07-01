#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <openssl/crypto.h>
#include "entry.h"

int main(int argc, char *argv[]) {
    async_ssl_init();

    signal(SIGPIPE, SIG_IGN);
    if (argc >= 2) {
        start_beaver(argv[1]);
    } else {
        start_beaver("config.yaml");
    }

    async_ssl_deinit();
    return 0;
}
