---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/14 11:09 PM
---

require("eclass")

local system = require("common.system")
local CasyncBase = require("async.asyncBase")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local class = class
local CasyncTimer = class("asyncTimer", CasyncBase)

local liteAssert = system.liteAssert
local coReport = system.coReport
local running = coroutine.running
local yield = coroutine.yield
local resume = coroutine.resume
local format = string.format
local timer_io_init = c_api.timer_io_init
local timer_io_get = c_api.timer_io_get
local timer_io_set = c_api.timer_io_set

function CasyncTimer:_init_(beaver, toWake)
    local fd = timer_io_init()
    liteAssert(fd > 0, "setup timer io failed.")
    self._toWake = toWake

    CasyncBase._init_(self, beaver, fd, -1)
end

function CasyncTimer:_setup(fd)
    local res, msg
    local co = self._toWake

    while true do
        local e = yield()

        if e.ev_close > 0 then  -- should never occur.
            break
        end

        res = timer_io_get(fd)
        if res == 0 then
            res, msg = resume(co, 0)  -- to wake up masterTimer.
            coReport(co, res, msg)
        end
    end
    self:stop()
end

function CasyncTimer:update(ms)
    local res
    res = timer_io_set(self._fd, ms)
    liteAssert(res >= 0, format("set timer_io value failed %d", ms))
end

return CasyncTimer
