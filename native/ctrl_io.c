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
    char buf[BEAVER_BUF];

    if (len > BEAVER_BUF - sizeof (int)) {
        ret = -EINVAL;
        goto endValue;
    }
    memcpy(buf, &len, sizeof (len));
    memcpy(buf + 4, msg, len);

    retryBlock:
    ret = write(fd, buf, len + sizeof (int));
    if (ret < 0) {
        if (ret == -EAGAIN) {
            goto retryBlock;
        }
        goto endWrite;
    }
    return ret;

    endWrite:
    endValue:
    return ret;
}
