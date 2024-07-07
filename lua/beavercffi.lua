---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/14 2:59 PM
---

local c_type = require("ffi")
local c_api = c_type.load('lbeaver')
c_type.cdef [[
typedef struct native_event {
    int fd;
    short int ev_in;
    short int ev_out;
    short int ev_close;
}native_event_t;

typedef struct native_events {
    int num;
    native_event_t evs[256];
}native_events_t;

typedef unsigned long pthread_t;
pthread_t create_beaver(int ctrl_in, int ctrl_out, const char* name, const char *config);

int init(int listen_fd);
int add_fd(int efd, int fd);
int mod_fd(int efd, int fd, int wr);
int mod_fd_block(int fd, int block);
int del_fd(int efd, int fd);
int poll_fds(int efd, int tmo, native_events_t* nes);
int setsockopt_reuse_port(int fd);
int check_connected(int fd);
int b_read(int fd, void *buf, int count);
int b_write(int fd, void *buf, int count);
int b_socket(int domain, int type, int protocol);
int b_accept(int fd);
int b_listen(int fd, int backlog);
int b_bind_ip(int fd, const char* ip, unsigned short port);
int b_bind_uds(int fd, const char* path);
int b_connect_ip(int fd, const char* ip, unsigned short port);
int b_connect_uds(int fd, const char* path);

void b_yield(void);
int b_close(int fd);
void deinit(int efd);

int ssl_read(void *handle, char *buff, int len);
int ssl_write(void *handle, const char *buff, int len);
void *ssl_connect_pre(int fd);
int ssl_connect(void * handle);
void ssl_del(void *handle);

int timer_io_init(void);
unsigned long timer_io_now();
unsigned long time_io_calc(unsigned long offset);
int timer_io_set(int fd, unsigned long ms);
int timer_io_get(int fd);

int vsock_socket(int type, int protocol);
int vsock_bind(int sockfd, unsigned int cid, unsigned short port);
int vsock_connect(int sockfd, unsigned int cid, unsigned short port);
]]

return {type = c_type, api=c_api}
