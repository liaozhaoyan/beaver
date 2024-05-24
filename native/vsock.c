#include "vsock.h"
#include <sys/socket.h>
#include <linux/vm_sockets.h>
#include <errno.h>

int vsock_socket(int type, int protocol){
    return socket(AF_VSOCK, type, protocol);
}

int vsock_bind(int sockfd, unsigned int cid, unsigned short port){
    int ret;
    struct sockaddr_vm addr = {
        .svm_family = AF_VSOCK,
        .svm_cid = cid,
        .svm_port = port,
    };
    ret = bind(sockfd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0) {
        return errno;
    }
    return 0;
}

int vsock_connect(int sockfd, unsigned int cid, unsigned short port) {
    int ret;
    struct sockaddr_vm addr = {
        .svm_family = AF_VSOCK,
        .svm_cid = cid,
        .svm_port = port,
    };
    ret = connect(sockfd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0) {
        return errno;
    }
    return 0;
}
