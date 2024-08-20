//
// Created by 廖肇燕 on 2023/12/30.
//

#ifndef BEAVER_LUA_API_H
#define BEAVER_LUA_API_H

#include <lauxlib.h>
#include <lualib.h>
int lua_reg_errFunc(lua_State *L);
int lua_check_ret(int ret);
int lua_load_do_file(lua_State *L, const char* path);
int lua_add_path(lua_State *L, const char *name, const char *value);

#endif //BEAVER_LUA_API_H
