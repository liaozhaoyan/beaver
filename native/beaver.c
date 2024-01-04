//
// Created by 廖肇燕 on 2023/12/30.
//
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include "lua_api.h"
#include "ctrl_io.h"
#include "beaver.h"

static int call_init(lua_State *L, int err_func, struct beaver_init_args * args) {
    int ret;
    lua_Number lret;

    lua_getglobal(L, "init");
    lua_pushnumber(L, args->ctrl_in);
    lua_pushnumber(L, args->ctrl_out);
    lua_pushstring(L, args->name);
    lua_pushstring(L, args->config);
    ret = lua_pcall(L, 4, 1, err_func);
    if (ret) {
        lua_check_ret(ret);
        goto endCall;
    }

    if (!lua_isnumber(L, -1)) {   // check
        errno = -EINVAL;
        perror("function beaver.lua init must return a number.");
        goto endReturn;
    }
    lret = lua_tonumber(L, -1);
    lua_pop(L, 1);
    if (lret < 0) {
        errno = -EINVAL;
        ret = -1;
        perror("beaver.lua init failed.");
        goto endReturn;
    }

    return ret;
    endReturn:
    endCall:
    return ret;
}

static int beaver_work(lua_State *L) {
    int ret;
    int err_func;
    lua_Number lret;

    err_func = lua_gettop(L);
    lua_getglobal(L, "work");
    ret = lua_pcall(L, 0, 1, err_func);
    if (ret) {
        lua_check_ret(ret);
        goto endCall;
    }

    if (!lua_isnumber(L, -1)) {   // check
        errno = -EINVAL;
        perror("function beaver.lua work must return a number.");
        goto endReturn;
    }
    lret = lua_tonumber(L, -1);
    lua_pop(L, 1);
    if (lret < 0) {
        errno = -EINVAL;
        ret = -1;
        perror("beaver.lua work failed.");
        goto endReturn;
    }

    return ret;
    endReturn:
    endCall:
    return ret;
}

static lua_State * app_init(struct beaver_init_args* args) {
    int ret;
    int err_func;

    /* create a state and load standard library. */
    lua_State *L = luaL_newstate();
    if (L == NULL) {
        perror("new lua failed.");
        goto endNew;
    }

    /* opens all standard Lua libraries into the given state. */
    luaL_openlibs(L);
    lua_add_path(L, "path", "../lua/?.lua");
    lua_add_path(L, "path", "/usr/share/lua/5.1/?.lua");
    lua_add_path(L, "cpath", "/usr/lib64/lua/5.1/?.so");
    err_func = lua_reg_errFunc(L);

    ret = lua_load_do_file(L, "../lua/beaver.lua");
    if (ret) {
        goto endLoad;
    }

    ret = call_init(L, err_func, args);
    if (ret < 0) {
        goto endCall;
    }

    free(args);
    return L;
    endCall:
    endLoad:
    lua_close(L);
    endNew:
    free(args);
    return NULL;
}

#define MSG_BUF 32
static void * beaver_app(void * arg) {
    struct beaver_init_args *args = (struct beaver_init_args *)arg;
    int ctrl_out = args->ctrl_out;
    int ctrl_in  = args->ctrl_in;
    char name[BEAVER_COMM_LEN];

    memcpy(name, args->name, BEAVER_COMM_LEN);

    lua_State *L = app_init(args);
    if (L != NULL) {
        beaver_work(L);
    }

    if (ctrl_out) {
        char msg[MSG_BUF];
        int len;
        len = snprintf(msg, MSG_BUF, "{\"func\":\"beaver_exit\",\"arg\":{\"name\":\"%s\"}}", name);
        ctrl_write(ctrl_out, msg, len);

        read(ctrl_in, msg, MSG_BUF);
        // fd will close in pthread exit.
    }
    return NULL;
}

static int _create_beaver(pthread_t *p_tid, struct beaver_init_args* args) {
    int ret;

    //local arg will free in thread function.
    struct beaver_init_args *local = malloc(sizeof (struct beaver_init_args));
    if (local == NULL) {
        errno = -ENOMEM;
        perror("malloc for beaver args failed.");
        goto endMalloc;
    }

    memcpy(local, args, sizeof (struct beaver_init_args));

    ret = pthread_create(p_tid, NULL, beaver_app, local);
    if (ret == 0) {
        pthread_setname_np(*p_tid, local->name);
    } else {
        perror("create beaver thread failed.");
        goto endPthread;
    }
    return ret;

    endPthread:
    free(local);
    endMalloc:
    return ret;
}

pthread_t create_beaver(int ctrl_in, int ctrl_out,
                        char* name, char *config) {
    pthread_t tid;
    int ret;
    struct beaver_init_args args;

    if (strlen(name) >= BEAVER_COMM_LEN) {
        errno = -EINVAL;
        fprintf(stderr, "bad beaver task %s\n", name);
        perror("bad beaver task name, size overflow.");
        return 0;
    }
    args.ctrl_in = ctrl_in;
    args.ctrl_out = ctrl_out;
    args.config = config;
    snprintf(args.name, BEAVER_COMM_LEN, "%s", name);

    ret = _create_beaver(&tid, &args);
    if (ret < 0) {
        return 0;
    }
    return tid;
}
