---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 3:01 PM
---

require("eclass")

local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local ChttpServer = class("httpServer", CasyncBase)

function ChttpServer:_init_(beaver, fd, bfd, addr, conf, inst, tmo)
    self._beaver = beaver
    self._inst = inst

    tmo = tmo or 10
    self._bfd = bfd
    self._addr = addr
    self._conf = conf

    CasyncBase._init_(self, beaver, fd, tmo)
end

function ChttpServer:_setup(fd, tmo)
    local beaver = self._beaver
    local module = self._conf.func

    local inst = self._inst
    local session = {}

    workVar.clientAdd(module, self._bfd, fd, coroutine.running(), self._addr)
    while true do
        local fread = beaver:reads(fd)
        local tReq = inst:proc(fread, session)

        if tReq then
            beaver:co_set_tmo(fd, tmo)
            local s = inst:packServerFrame(tReq)
            beaver:write(fd, s)
        else
            print(string.format("fd %d closed", fd))
            break
        end
    end
    self:stop()
    c_api.b_close(fd)
    workVar.clientDel(module, fd)
end

return ChttpServer
