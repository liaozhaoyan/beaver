//
// Created by 廖肇燕 on 2023/12/30.
//

#include "ctrl_io.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#define BEAVER_BUF  4096

int ctrl_write(int fd, char * msg, int len) {
    int ret;
    char buf[BEAVER_BUF] = {0};
    int full_len = len + sizeof(int);

    if (full_len > BEAVER_BUF) {
        ret = -EINVAL;
        goto endValue;
    }
    memcpy(buf, &len, sizeof(int));
    memcpy(buf + sizeof(int), msg, len);

    retryBlock:
    ret = write(fd, buf, full_len);
    if (ret < 0) {
        if (errno == EAGAIN) {
            goto retryBlock;
        }
        goto endWrite;
    }
    return ret;

    endWrite:
    endValue:
    return ret;
}
