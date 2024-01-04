//
// Created by 廖肇燕 on 2023/12/30.
//

#include "lua_api.h"
#include <stdio.h>
#include <string.h>
#include <errno.h>

static int lua_traceback(lua_State *L)
{
    const char *errmsg = lua_tostring(L, -1);
    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_call(L, 0, 1);
    printf("%s \n%s\n", errmsg, lua_tostring(L, -1));
    return 1;
}

int lua_reg_errFunc(lua_State *L) {
    lua_pushcfunction(L, lua_traceback);
    return lua_gettop(L);
}

int lua_check_ret(int ret) {
    switch (ret) {
        case 0:
            break;
        case LUA_ERRRUN:
            printf("lua runtime error.\n");
            break;
        case LUA_ERRMEM:
            printf("lua memory error.\n");
        case LUA_ERRERR:
            printf("lua exec error.\n");
        case LUA_ERRSYNTAX:
            printf("file syntax error.\n");
        case LUA_ERRFILE:
            printf("load lua file error.\n");
        default:
            printf("bad res for %d\n", ret);
            break;
    }
    return ret;
}

int lua_load_do_file(lua_State *L, const char* path) {
    int err_func = lua_gettop(L);
    int ret;

    ret = luaL_loadfile(L, path);
    if (ret) {
        return lua_check_ret(ret);
    }
    ret = lua_pcall(L, 0, LUA_MULTRET, err_func);
    return lua_check_ret(ret);
}

#define LUA_PATH_MAX 1024
int lua_add_path(lua_State *L, const char *name, const char *value) {
    int ret = 0;
    int len;
    char s[LUA_PATH_MAX];

    lua_getglobal(L, "package");
    lua_getfield(L, -1, name);
    len = snprintf(s, LUA_PATH_MAX, "%s;%s", lua_tostring(L, -1), value);
    if (len == LUA_PATH_MAX) {
        fprintf(stderr, "lua global path %s may be overflowed.\n", name);
        ret = -ENOMEM;
    }
    lua_pushstring(L, s);
    lua_setfield(L, -3, name);
    lua_pop(L, 2);
    return ret;
}
