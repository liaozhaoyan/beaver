---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 3:01 PM
---

require("eclass")

local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")
local sockComm = require("common.sockComm")

local class = class
local ChttpServer = class("httpServer", CasyncBase)

local pairs = pairs
local type = type
local running = coroutine.running
local yield = coroutine.yield
local srvSslHandshake = sockComm.srvSslHandshake

function ChttpServer:_init_(beaver, fd, bfd, addr, conf, inst, ctx)
    self._beaver = beaver
    self._inst = inst

    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    self._ctx = ctx

    CasyncBase._init_(self, beaver, fd, 10)
end

function ChttpServer:_setup(fd, tmo)
    local beaver = self._beaver
    local module = self._conf.func
    local gzip = self._conf.gzip

    local inst = self._inst
    local session = {}
    local clients = {}
    local ret = 1
    local ctx = self._ctx

    beaver:co_set_tmo(fd, tmo)
    workVar.clientAdd(module, self._bfd, fd, running(), self._addr)
    if ctx then
        ret = srvSslHandshake(beaver, fd, ctx)
    end

    if ret == 1 then
        while true do
            local e = yield()
            if type(e) ~= "cdata" or e.ev_in < 1 then
                break
            end
       
            local fread = beaver:reads(fd, nil, tmo / 2)
            local tRes = inst:proc(fread, session, clients, beaver, fd, gzip)

            if tRes then
                local vec = inst:packServerFrame(tRes)
                beaver:writev(fd, vec)
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
    end

    self:stop()
    workVar.clientDel(module, fd)
end

return ChttpServer
