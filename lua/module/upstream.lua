---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/6 3:51 PM
---

require("eclass")

local psocket = require("posix.sys.socket")
local system = require("common.system")
local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")
local sockComm = require("module.sockComm")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local Cdownstream = class("nextstream", CasyncBase)

function Cdownstream:_init_(beaver, uplink, bfd, addr, conf, tmo)
    self._status = 0  -- 0:disconnect, 1 connected, 2 connecting

    self._beaver = beaver
    tmo = tmo or 10
    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    self._uplink = uplink

    local tPort = {}
    if conf.upPort then
        tPort = {family=psocket.AF_INET, addr=conf.upIP, port=conf.upPort}
    elseif conf.upUniSock then
        tPort = {family=psocket.AF_UNIX, path=conf.upUniSock}
    end

    local fd = sockComm.connectSetup(tPort)
    self._tPort = tPort

    CasyncBase._init_(self, beaver, fd, tmo)
end

function Cdownstream:_setup(fd, tmo)
    local beaver = self._beaver
    local conf = self._conf
    local uplink = self._uplink
    local res

    workVar.clientAdd(conf.func, self._bfd, fd, coroutine.running(), self._addr)

    self._status = 2  -- connecting
    beaver:co_set_tmo(fd, tmo)  -- set connect timeout
    res = sockComm.connect(fd, self._tPort, beaver)
    beaver:co_set_tmo(fd, -1)   -- back
    self._status = res  -- connected
    uplink:connectWake(res)
    if res ~= 1 then   -- connect failed
        print("connect failed.", res)
        goto stopStream
    end

    while true do
        local e = coroutine.yield()
        local t = type(e)
        if t == "string" then -- read stream from uplink
            beaver:co_set_tmo(fd, tmo)
            res = beaver:write(fd, e)
            if not res then
                break
            end
            beaver:co_set_tmo(fd, -1)
        elseif t == "nil" then  -- uplink closed
            break
        else  -- read event.
            if e.ev_close > 0 then
                break
            elseif e.ev_in > 0 then
                local s = beaver:read(fd)
                if not s then
                    break
                end
                uplink:send(s)
            else
                print("IO Error.")
                break
            end
        end
    end

    ::stopStream::
    self._status = 0
    uplink:shutdown()
    self:stop()
    c_api.b_close(fd)
    workVar.clientDel(conf.func, fd)
end

function Cdownstream:send(s)
    local res, msg
    local co = self._co
    if coroutine.status(co) == "suspended" then
        res, msg = coroutine.resume(co, s)
        system.coReport(co, res, msg)
    end
end

function Cdownstream:shutdown()  -- send a nil message
    local res, msg
    local co = self._co
    if coroutine.status(co) == "suspended" then
        res, msg = coroutine.resume(co, nil)
        system.coReport(co, res, msg)
    end
end

function Cdownstream:status()
    return self._status
end

local Cupstream = class("upstream", CasyncBase)

function Cupstream:_init_(beaver, fd, bfd, addr, conf, inst, tmo)
    self._beaver = beaver
    tmo = tmo or 10
    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    CasyncBase._init_(self, beaver, fd, tmo)
end

local function waitConnect(beaver, fd, down)
    local res = down:status()
    if res == 1 then -- connect ok.
        return true
    elseif res == 2 then -- connecting
        beaver:mod_fd(fd, -1)  -- mask io event, other close event is working.
        local w = coroutine.yield()
        local t = type(w)
        if t == "number" and w == 1 then  -- 0 is ok
            beaver:mod_fd(fd, 0)  -- back to read mode
            return true
        else
            if t ~= "number" then
                print("wake from client.", t, w, w.ev_close, w.ev_in, w.ev_out)
            end
            return false
        end
    else  -- not connect
        return false
    end
end

function Cupstream:_setup(fd, tmo)
    local beaver = self._beaver
    local conf = self._conf
    local res

    workVar.clientAdd(conf.func, self._bfd, fd, coroutine.running(), self._addr)

    local down = Cdownstream.new(beaver, self, self._bfd, self._addr, conf)
    if not waitConnect(beaver, fd, down) then
        goto stopStream
    end

    while true do
        local e = coroutine.yield()
        local t = type(e)
        if t == "string" then -- read stream from uplink
            beaver:co_set_tmo(fd, tmo)
            res = beaver:write(fd, e)
            if not res then
                break
            end
            beaver:co_set_tmo(fd, -1)
        elseif t == "nil" then  -- uplink closed
            break
        else  -- read event.
            if e.ev_close > 0 then
                break
            elseif e.ev_in > 0 then
                local s = beaver:read(fd)
                if not s then
                    break
                end
                down:send(s)
            else
                print("IO Error.")
                break
            end
        end
    end

    ::stopStream::
    down:shutdown()
    self:stop()
    c_api.b_close(fd)
    workVar.clientDel(conf.func, fd)
end

function Cupstream:send(s)
    local res, msg
    local co = self._co
    if coroutine.status(co) == "suspended" then
        res, msg = coroutine.resume(co, s)
        system.coReport(co, res, msg)
    end
end

function Cupstream:shutdown()  -- send a nil message
    local res, msg
    local co = self._co
    if coroutine.status(co) == "suspended" then
        res, msg = coroutine.resume(co, nil)
        system.coReport(co, res, msg)
    end
end

function Cupstream:connectWake(v)  -- send a nil message
    local res, msg
    local co = self._co
    if coroutine.status(co) == "suspended" then
        res, msg = coroutine.resume(co, v)
        system.coReport(co, res, msg)
    end
end

return Cupstream
