---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/3 4:37 AM
---

require("eclass")

local system = require("common.system")
local CasyncBase = require("async.asyncBase")

local class = class
local CasyncPipeWrite = class("asyncPipeWrite", CasyncBase)

local ipairs = ipairs
local type = type
local print = print
local coReport = system.coReport
local running = coroutine.running
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local format = string.format

function CasyncPipeWrite:_init_(beaver, fd, tmo)
    self._toWake = running()
    self._tmo = tmo
    CasyncBase._init_(self, beaver, fd, -1)
end

function CasyncPipeWrite:_setup(fd, tmo)
    local res, msg
    local co = self._toWake
    self._coSelf = running()

    local beaver = self._beaver
    tmo = self._tmo
    beaver:co_set_tmo(fd, tmo)
    while true do
        local stream = yield()
        if type(stream) == "string" then
            local ret, err, errno = beaver:pipeWrite(fd, stream)  -->pipe write may yield out
            if status(co) == "normal" then  --> write not yield
                yield(ret, err, errno)
            else
                res, msg = resume(co, ret, err, errno)
                coReport(co, res, msg)
            end

            if not ret then -- fd close event?
                print(format("pipe write fd %d closed.", fd))
                break
            end
        else  -- fd close event?
            print(format("write fd %d closed. for event", fd))
            break
        end
    end
    self:stop()
end

function CasyncPipeWrite:write(stream)
    local res, msg, err, errno = resume(self._coSelf, stream)
    coReport(self._coSelf, res, msg)
    if msg then  -- write function may write to pipe, if stream is short enough, write will return at once
        local ret = msg
        res, msg = resume(self._coSelf)  -->task will yield after write success.
        coReport(self._coSelf, res, msg)
        return ret, err, errno
    else --> the pipe call from if stream is too long, the task may be yield.
        return yield()
    end
end

return CasyncPipeWrite