//
// Created by 廖肇燕 on 2023/2/14.
//

#define _GNU_SOURCE
#include "local_beaver.h"
#include <sys/epoll.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <fcntl.h>
#include <unistd.h>
#include <sched.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "async_ssl.h"

#define EPOLL_CLOSE_FLAG (EPOLLERR | EPOLLHUP | EPOLLRDHUP)

int del_fd(int efd, int fd);

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
        fprintf(stderr, "fd:%d\n", sfd);
        perror("error : cannot get socket flags!\n");
        return -errno;
    }

    flags &= ~O_NONBLOCK;
    ret    = fcntl(sfd, F_SETFL, flags);
    if (ret < 0) {
        fprintf(stderr, "fd:%d\n", sfd);
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

    memset(&event, 0, sizeof(struct epoll_event));
    event.events  = EPOLLIN | EPOLLERR | EPOLLRDHUP;  // read only default.
    event.data.fd = fd;

    ret = epoll_ctl(efd, EPOLL_CTL_ADD, fd, &event);
    if (ret < 0) {
        fprintf(stderr, "fd:%d\n", fd);
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

    efd = epoll_create1(EPOLL_CLOEXEC);
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

    memset(&event, 0, sizeof(struct epoll_event));
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
        case -2:  //already cloesed, do not trig any more.
            return del_fd(efd, fd);
        case -3:  //for case 2, add fd back to epoll fd, 
            // then will remove it by beaverIO:remove(fd)
            return add_fd(efd, fd);
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
    return ret;
}

int poll_is_in(native_cell_t* ev) {
    return ev->events & EPOLLIN ? 1 : 0;
}

int poll_is_out(native_cell_t* ev) {
    return ev->events & EPOLLOUT ? 1 : 0;
}

int poll_is_close(native_cell_t* ev) {
    return ev->events & EPOLL_CLOSE_FLAG ? 1 : 0;
}

int poll_fds(int efd, int tmo, native_events_t* nes) {
    struct epoll_event events[NATIVE_EVENT_MAX];
    int i, ret = 0;

    ret = epoll_wait(efd, events, NATIVE_EVENT_MAX, tmo * 1000);
    if (ret < 0 && errno != EINTR) {   // EINTR should count as a normal event
        perror("error : epoll failed!\n");
        return -errno;
    }

    if (ret < 0) {
        nes->num = 0;
        return 0;    
    }
    nes->num = ret;
    for (i = 0; i < ret; i ++) {
        nes->evs[i].fd = events[i].data.fd;
        nes->evs[i].events = events[i].events;
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

int b_socket(int domain, int type, int protocol) {
    int ret;
    ret = socket(domain, type, protocol);
    if (ret < 0) {
        return errno;
    }
    return ret;
}

int b_accept(int fd) {
    int ret;
    ret = accept(fd, NULL, NULL);
    if (ret < 0) {
        return errno;
    }
    return ret;
}

int b_listen(int fd, int backlog) {
    int ret;
    ret = listen(fd, backlog);
    if (ret < 0) {
        return errno;
    }
    return 0;
}

int b_bind_ip(int fd, const char* ip, unsigned short port) {
    struct sockaddr_in addr;
    int ret;
    if (ip == NULL) {
        return EINVAL;
    }

    bzero(&addr, sizeof(addr)); 
    addr.sin_family = AF_INET; 
    addr.sin_addr.s_addr = inet_addr(ip); 
    addr.sin_port = htons(port); 
    ret = bind(fd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0) {
        return errno;
    }
    return 0;
}

int b_bind_uds(int fd, const char* path) {
    struct sockaddr_un addr;
    int ret;
    if (path == NULL) {
        return EINVAL;
    }

    bzero(&addr, sizeof(addr)); 
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path);
    ret = bind(fd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0) {
        return errno;
    }
    return 0;
}

int b_connect_ip(int fd, const char* ip, unsigned short port) {
    struct sockaddr_in addr;
    int ret;

    if (ip == NULL) {
        return EINVAL;
    }

    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(ip);
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        printf("bad ip: %s\n", ip);
        return EINVAL;
    }
    bzero(&(addr.sin_zero), sizeof(addr.sin_zero));
    ret = connect(fd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0) {
        return errno;
    }
    return 0;
}

int b_connect_uds(int fd, const char* path) {
    struct sockaddr_un addr;
    int ret;

    if (path == NULL) {
        return EINVAL;
    }

    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", path);
    ret = connect(fd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0) {
        return errno;
    }
    return 0;
}

int b_read(int fd, void *buf, int count) {
    int ret = read(fd, buf, count);
    if (ret < 0) {
        return -errno;
    }
    return ret;
}

int b_write(int fd, const char* buf, int offset, int count) {
    int ret = write(fd, buf + offset, count);
    if (ret < 0) {
        return -errno;
    }
    return ret;
}

int b_writev(int fd, const struct iovec *iov, int iovcnt) {
    int ret = writev(fd, iov, iovcnt);
    if (ret < 0) {
        return -errno;
    }
    return ret;
}

void b_yield(void) {
    sched_yield();
}

int b_close(int fd) {
    int ret = close(fd);
    if (ret < 0) {
        perror("error : close fd failed!\n");
        return -errno;
    }
}

void deinit(int efd) {
    close(efd);
}
