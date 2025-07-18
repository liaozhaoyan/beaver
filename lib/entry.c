//
// Created by 廖肇燕 on 2023/12/30.
//

#include "entry.h"
#include "beaver.h"
#include "ctrl_io.h"
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

static int fd_size(int fd) {
    int ret;
    struct stat file_info;

    ret = fstat(fd, &file_info);
    if (ret < 0) {
        perror("stat config file filed.");
    }
    return (!ret) ? file_info.st_size : -EACCES;
}

int is_thread_alive(pthread_t thread) {
    int result = pthread_kill(thread, 0);
    if (result == 0) {
        return 1; // Thread is alive
    } else if (result == ESRCH) {
        return 0; // Thread does not exist (not alive)
    } else {
        // Other error occurred
        fprintf(stderr, "Error checking thread status: %d\n", result);
        return -1; // Indicate an error
    }
}

static int add_little_endian_ul(char* msg, int index, unsigned long value) {
    int i;
    msg[index ++] = 0x11;  // 0x11 is for unsigned long
    for (i = 0; i < 8; i++) {
        msg[index + i] = (value >> (8 * i)) & 0xFF;
    }
    return index + 8;
}

#define BEAVER_MASTER_DETECT_LOOP 3
#define MSG_SIZE 64
int start_beaver(char * path) {
    int ret = -1;
    int size, len;
    char *s;
    char msg[MSG_SIZE];
    pthread_t tid;

    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        perror("open config file failed.");
        goto endFile;
    }

    size = fd_size(fd);
    if (size < 0) {
        goto endSize;
    }

    s = malloc(size + 1);
    if (s == NULL) {
        perror("malloc for config failed.");
        goto endMalloc;
    }

    len = read(fd, s, size);
    if (len < 0) {
        perror("read config failed.");
        goto endReadConfig;
    }
    s[size] = '\0';

    int pipeR[2];   // 0 for read, 1 for write, for master Read
    int pipeW[2];   // for master Write.
    if (pipe(pipeR) < 0) {
        perror("create r pipe failed.");
        goto endPipeRead;
    }
    if (pipe(pipeW) < 0) {
        goto endPipeWrite;
    }

    // create master
    tid = create_beaver(pipeR[0], pipeW[1], "master", s);
    if (tid == 0) {
        perror("create beaver thread failed.");
        goto endThread;
    }

    const char *ctrlReg = "\x0C\x04\x2B\x70\x69\x70\x65\x43\x74\x72\x6C\x52\x65\x67";  // lua table, has 3 cell ,fist is string pipeCtrlReg
    memcpy(msg, ctrlReg, strlen(ctrlReg));
    int index = strlen(ctrlReg);
    index = add_little_endian_ul(msg, index, pipeR[1]);  // next is int masterIn
    index = add_little_endian_ul(msg, index, pipeW[0]);  // next is int masterOut

    // 0 for read, 1 for write, for master Read
    printf("pipeCtrlReg: %d\n", index);
    ret = ctrl_write(pipeR[1], msg, index);   // 1 is for write
    if (ret < 0) {
        goto endPipeReg;
    }

    ret = read(pipeW[0], msg, MSG_SIZE);
    if (ret < 0) {
        printf("read: %d\n", pipeW[0]);
        perror("read master pipe failed.");
        goto endPipeReg;
    }

    while (1) {
        int ret;
        sleep(BEAVER_MASTER_DETECT_LOOP);
        ret = is_thread_alive(tid);
        if (ret == 0) {
            fprintf(stderr, "beaver master thread exit.\n");
            exit(1);
        } else if (ret < 0) {
            break;
        }
    }

    // register pipe, never run how.
    const char* masterExit = "\x0C\x02\x2A\x6D\x61\x73\x74\x65\x72\x45\x78\x69\x74";
    memcpy(msg, masterExit, strlen(masterExit));
    len = strlen(masterExit);
    ret = ctrl_write(pipeR[1], msg, len);   // 1 is for write
    if (ret < 0) {
        goto endMainExit;
    }

    ret = read(pipeW[0], msg, MSG_SIZE);
    if (ret < 0) {
        perror("read master pipe failed.");
        goto endMainExit;
    }

    close(pipeR[0]);
    close(pipeR[1]);
    close(pipeW[0]);
    close(pipeW[1]);

    free(s);
    close(fd);
    return 0;

    endMainExit:
    endPipeReg:
    close(pipeW[0]);
    close(pipeW[1]);
    endPipeWrite:
    close(pipeR[0]);
    close(pipeR[1]);
    endPipeRead:
    endThread:
    endReadConfig:
    free(s);
    endMalloc:
    endSize:
    close(fd);
    endFile:
    return ret;
}

