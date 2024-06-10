//
// Created by 廖肇燕 on 2023/2/14.
//

#define _GNU_SOURCE
#include "local_beaver.h"
#include <sys/epoll.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <unistd.h>
#include <sched.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "async_ssl.h"

int setsockopt_reuse_port(int fd){
    int opt =1;
    int r = setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, (char*)&opt, sizeof(int));
//    SO_REUSEPORT
    if (r < 0) {
        perror("set sock opt failed.");
    }
    return r;
}

static int fd_non_blocking(int sfd)
{
    unsigned int flags = 0;
    int ret = 0;

    flags = fcntl(sfd, F_GETFL);
    if (flags < 0) {
        perror("error : cannot get socket flags!\n");
        return -errno;
    }

    flags |= O_NONBLOCK;
    ret    = fcntl(sfd, F_SETFL, flags);
    if (ret < 0) {
        perror("error : cannot set socket flags!\n");
        ret = -errno;
        goto fcntlFailed;
    }

    return 0;
    fcntlFailed:
    return ret;
}

static int fd_blocking(int sfd)
{
    unsigned int flags = 0;
    int ret = 0;

    flags = fcntl(sfd, F_GETFL);
    if (flags < 0) {
        perror("error : cannot get socket flags!\n");
        return -errno;
    }

    flags &= ~O_NONBLOCK;
    ret    = fcntl(sfd, F_SETFL, flags);
    if (ret < 0) {
        perror("error : cannot set socket flags!\n");
        ret = -errno;
        goto fcntlFailed;
    }

    return 0;
    fcntlFailed:
    return ret;
}

static int epoll_add(int efd, int fd) {
    struct epoll_event event;
    int ret = 0;

    event.events  = EPOLLIN;
    event.data.fd = fd;

    ret = epoll_ctl(efd, EPOLL_CTL_ADD, fd, &event);
    if (ret < 0) {
        perror("error : can not add event to epoll!\n");
        return -errno;
    }
    return ret;
}

static int epoll_del(int efd, int fd) {
    int ret;

    ret = epoll_ctl(efd, EPOLL_CTL_DEL, fd, NULL);
    if (ret < 0) {
        perror("error : can not del event to epoll!\n");
        return -errno;
    }
    return ret;
}

int init(int listen_fd) {
    int efd = 0;
    int ret = 0;

    ret = async_ssl_init();
    if (ret < 0) {
        goto end_ssl_init;
    }

    efd = epoll_create(NATIVE_EVENT_MAX);
    if (efd < 0) {
        perror("error : cannot create epoll!\n");
        exit(1);
    }

    if (listen_fd > 0) {
        ret = epoll_add(efd, listen_fd);
        if (ret < 0) {
            ret = -errno;
            goto end_epoll_add;
        }
    }
    return efd;

    end_ssl_init:
    end_epoll_add:
    return ret;
}

int add_fd(int efd, int fd) {
    int ret;

    ret = fd_non_blocking(fd);
    if (ret < 0) {
        goto end_socket_non_blocking;
    }

    ret = epoll_add(efd, fd);
    if (ret < 0) {
        goto end_epoll_add;
    }
    return ret;

    end_socket_non_blocking:
    end_epoll_add:
    return ret;
}

int mod_fd(int efd, int fd, int wr) {
    struct epoll_event event;
    int ret;

    switch (wr) {
        case 1:   // write only
            event.events = EPOLLOUT | EPOLLERR | EPOLLRDHUP;
            break;
        case 0:   // read only
            event.events = EPOLLIN | EPOLLERR | EPOLLRDHUP;
            break;
        case -1:   //no read and write
            event.events = EPOLLERR | EPOLLRDHUP;
            break;
        default:
            fprintf(stderr, "bad wr mode %d for mod_fd", wr);
    }

    event.data.fd = fd;

    ret = epoll_ctl(efd, EPOLL_CTL_MOD, fd, &event);
    if (ret < 0) {
        perror("error : can no mod event to epoll!\n");
        return -errno;
    }
    return ret;
}

int mod_fd_block(int fd, int block) {
    return block ? fd_blocking(fd) : fd_non_blocking(fd);
}

int del_fd(int efd, int fd) {
    int ret;
    ret = epoll_del(efd, fd);

    close(fd);
    return ret;
}

int poll_fds(int efd, int tmo, native_events_t* nes) {
    struct epoll_event events[NATIVE_EVENT_MAX];
    int i, ret = 0;
    unsigned int close_flag = EPOLLERR | EPOLLHUP | EPOLLRDHUP;

    ret = epoll_wait(efd, events, NATIVE_EVENT_MAX, tmo * 1000);
    if (ret < 0) {
        perror("error : epoll failed!\n");
        return -errno;
    }
    nes->num = ret;
    for (i = 0; i < ret; i ++) {
        nes->evs[i].fd = events[i].data.fd;

        if (events[i].events & close_flag) {
            nes->evs[i].ev_close = 1;
        }
        if (events[i].events & EPOLLIN) {
            nes->evs[i].ev_in = 1;
        }
        if (events[i].events & EPOLLOUT) {
            nes->evs[i].ev_out = 1;
        }
    }
    return 0;
}

int check_connected(int fd) {
    int ret;
    int so_error;
    socklen_t len = sizeof(so_error);

    ret = getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_error, &len);
    if (ret < 0) {
        return -errno;
    }
    return so_error == 0 ? 0 : 1;
}

int b_read(int fd, void *buf, int count) {
    int ret = read(fd, buf, count);
    if (ret < 0) {
        return -errno;
    }
    return ret;
}

int b_write(int fd, void *buf, int count) {
    int ret = write(fd, buf, count);
    if (ret < 0) {
        return -errno;
    }
    return ret;
}

void b_yield(void) {
    sched_yield();
}

int b_close(int fd) {
    return close(fd);
}

void deinit(int efd) {
    close(efd);
    async_ssl_deinit();
}
