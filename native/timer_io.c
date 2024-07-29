//
// Created by 廖肇燕 on 2024/1/14.
//

#include "timer_io.h"
#include <sys/timerfd.h>
#include <inttypes.h> // For PRIu64
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>

int timer_io_init(void) {
    int timer_fd = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);  //close for child process.

    if (timer_fd == -1) {
        perror("timerfd_create");
        return -errno;
    }
    return timer_fd;
}

unsigned long timer_io_now() {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) == -1) {
        perror("clock_gettime");
        return 0;
    }
    return now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

unsigned long time_io_calc(unsigned long offset) {
    unsigned long now = timer_io_now();
    if (now == 0) {
        return 0;
    }
    return now + offset;
}

int timer_io_set(int fd, unsigned long ms) {
    struct itimerspec its;
    int sec, msec;

    if (ms == 0) {
        memset(&its, 0, sizeof(its));
        if (timerfd_settime(fd, 0, &its, NULL) < 0) {
            perror("timerfd_settime clear.");
            return -errno;
        }
        return 0;
    }
    sec = ms / 1000;
    msec = ms % 1000;

    its.it_value.tv_sec = sec;
    its.it_value.tv_nsec = msec * 1000000;
    its.it_interval.tv_sec = 0; // 不重复
    its.it_interval.tv_nsec = 0;

    if (timerfd_settime(fd, TFD_TIMER_ABSTIME, &its, NULL) < 0) {
        perror("timerfd_settime, set");
        return -errno;
    }

    return 0;
}

int timer_io_get(int fd) {
    int ret;
    unsigned long expirations;

    ret = read(fd, &expirations, sizeof(expirations));
    if (ret < 0) {
        perror("timer_fd read");
        return errno;
    }
    return 0;
}
