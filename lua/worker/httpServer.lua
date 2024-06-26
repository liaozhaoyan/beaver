---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 3:01 PM
---

require("eclass")

local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")

local class = class
local ChttpServer = class("httpServer", CasyncBase)

local pairs = pairs
local running = coroutine.running

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
    local clients = {}

    workVar.clientAdd(module, self._bfd, fd, running(), self._addr)
    local fread = beaver:reads(fd)
    while true do
        local tRes = inst:proc(fread, session, clients, beaver, fd)

        if tRes then
            beaver:co_set_tmo(fd, tmo)
            local s = inst:packServerFrame(tRes)
            beaver:write(fd, s)
            if tRes.keep == false then  -- do not keep alive any more.
                break
            end
        else
            break
        end
    end
    for client, _ in pairs(clients) do
        client:close()
    end
    self:stop()
    workVar.clientDel(module, fd)
end

return ChttpServer
