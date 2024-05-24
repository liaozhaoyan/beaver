#ifndef BEAVER_VSOCK_H
#define BEAVER_VSOCK_H

int vsock_socket(int type, int protocol);
int vsock_bind(int sockfd, unsigned int cid, unsigned short port);
int vsock_connect(int sockfd, unsigned int cid, unsigned short port);

#endif
