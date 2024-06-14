---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/1 1:41 AM
---
--- 2024.1.1: CcoBeaver is to manage all beaver coroutine events

require("eclass")

local system = require("common.system")
local CbeaverIO = require("beaverIO")

local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local class = class
local CcoBeaver = class("coBeaver", CbeaverIO)

local c_new = c_type.new
local liteAssert = system.liteAssert
local coReport = system.coReport
local c_api_poll_fds = c_api.poll_fds
local format = string.format
local time = os.time
local pairs = pairs
local error = error
local print = print
local create = coroutine.create
local resume = coroutine.resume
local status = coroutine.status

function CcoBeaver:_init_()
    CbeaverIO._init_(self)

    self._cos = {}
    self._last = time()
    self._tmoCos = {}
    self._tmoFd = {}
end

function CcoBeaver:_del_()
    CbeaverIO._del_(self)
end

function CcoBeaver:co_set_tmo(fd, tmo)
    liteAssert(tmo < 0 or tmo >= 2, format("illegal tmo value: %d, should >= 2.", tmo))
    self._tmoFd[fd] = tmo
    if tmo > 0 then
        self._tmoCos[fd] = time()
    end
end

function CcoBeaver:co_get_tmo(fd)
    return self._tmoFd[fd]
end

function CcoBeaver:co_add(obj, cb, fd, tmo)
    tmo = tmo or 60   -- default tmo time is 60s, -1 means never overtime.
    if tmo > 0 then
        liteAssert(tmo >= 2, "illegal tmo value, must >= 10.")
    end

    self:add(fd)  -- add to epoll fd
    local co = create(function(o, obj, fd, tmo)  cb(o, obj, fd, tmo) end)
    self._cos[fd] = co

    local res, msg = resume(co, obj, fd, tmo)
    coReport(co, res, msg)
    return co
end

function CcoBeaver:co_exit(fd)
    self:remove(fd)
    self._tmoFd[fd] = nil
    self._cos[fd] = nil
    self._tmoCos[fd] = nil
end

function CcoBeaver:_co_check(now, checkedFd)
    local res, msg
    -- ! coroutine will del self._tmoCos cell in loop, so create a mirror table for safety
    --local tmos = dictCopy(self._tmoCos)
    for fd, tmo in pairs(self._tmoCos) do
        if checkedFd[fd] then  -- the fd has last checked.
            goto continue
        end
        local tmoFd = self._tmoFd[fd]  -- tmoFd record the socket fd set over time
        if tmoFd and tmoFd > 0 and now - tmo >= tmoFd then  -- overtime
            local co = self._cos[fd]
            if co and status(co) == "suspended" then
                local e = c_type.new("native_event_t")  -- need to close this fd
                e.ev_close = 1   -- timeout close.
                e.fd = fd
                print(fd, "is over time.", tmo, now - tmo)
                res, msg = resume(co, e)
                coReport(co, res, msg)
            end
        end
        ::continue::
    end
    if now - self._last >= 1 then
        self._last = now
    end
end

-- 
function CcoBeaver:_pollFd(nes, checkedFd)
    local now_time = time()
    for i = 0, nes.num - 1 do
        local e = nes.evs[i];
        local fd = e.fd

        local co = self._cos[fd]
        -- assert(co, string.format("fd: %d not setup.", fd))
        if co and status(co) == "suspended" then -- coroutine event may closed.
            self._tmoCos[fd] = now_time
            checkedFd[fd] = now_time
            local res, msg = resume(co, e)
            system.coReport(co, res, msg)
        end
    end
    if now_time - self._last >= 1 then
        self:_co_check(now_time, checkedFd)
        self._last = now_time
        return 1  -- need clear checkedFd
    end
    return 0
end

function CcoBeaver:poll()
    local efd = self._efd
    local checkedFd = {}
    while true do
        local nes = c_new("native_events_t")
        local res = c_api_poll_fds(efd, 1, nes)

        if res < 0 then
            error(format("epoll failed, errno: %d", -res))
        end

        if self:_pollFd(nes, checkedFd) > 0 then
            checkedFd = {}
        end
    end
end

return CcoBeaver
