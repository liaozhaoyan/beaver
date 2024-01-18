---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/5 1:43 PM
---

require("eclass")

local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local Cpingpong = class("pinngpong", CasyncBase)

function Cpingpong:_init_(beaver, fd, bfd, addr, conf, tmo)
    self._beaver = beaver
    tmo = tmo or 10
    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    CasyncBase._init_(self, beaver, fd, tmo)
end

function Cpingpong:_setup(fd, tmo)
    local beaver = self._beaver
    local module = self._conf.func

    workVar.clientAdd(module, self._bfd, fd, coroutine.running(), self._addr)
    while true do
        beaver:co_set_tmo(fd, -1)
        local s = beaver:read(fd)
        if not s then
            break
        end
        beaver:co_set_tmo(fd, tmo)
        local res = beaver:write(fd, s)
        if not res then
            break
        end
    end
    self:stop()
    c_api.b_close(fd)
    workVar.clientDel(module, fd)
end

return Cpingpong