---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/3 4:15 AM
---

require("eclass")

local system = require("common.system")
local CasyncBase = require("async.asyncBase")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local CasyncPipeRead = class("asyncPipeRead", CasyncBase)

function CasyncPipeRead:_init_(beaver, fd, tmo)
    self._toWake = coroutine.running()
    tmo = tmo or 10
    CasyncBase._init_(self, beaver, fd, tmo)
end

function CasyncPipeRead:_setup(fd, tmo)
    local res, msg
    local co = self._toWake

    coroutine.yield()  -- wait to poll wake up.

    local beaver = self._beaver
    while true do
        local stream, err, errno = beaver:pipeRead(fd)
        res, msg = coroutine.resume(co, stream, err, errno)
        system.coReport(co, res, msg)
        if not stream then
            print(string.format("pipe read fd %d closed.", fd))
            break
        end
    end
    self:stop()
    c_api.b_close(fd)
end

function CasyncPipeRead:read()
    return coroutine.yield()
end

return CasyncPipeRead