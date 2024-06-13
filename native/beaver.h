//
// Created by 廖肇燕 on 2023/12/30.
//

#ifndef BEAVER_BEAVER_H
#define BEAVER_BEAVER_H

#include <pthread.h>
#define BEAVER_COMM_LEN 32

typedef struct beaver_init_args{
    int ctrl_in;       // control stream in encode by json, msg size should less than PIPE_BUF(4K)
    int ctrl_out;       // control stream out encode by json
    char name[BEAVER_COMM_LEN];    // task name  only one master
    char *config;  // config stream, encode by yaml
}beaver_init_args_t;

pthread_t create_beaver(int ctrl_in, int ctrl_out, char* name, char *config);

#endif //BEAVER_BEAVER_H
