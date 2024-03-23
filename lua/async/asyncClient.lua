require("eclass")

local system = require("common.system")
local sockComm = require("common.sockComm")
local CasyncBase = require("async.asyncBase")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api
local format = string.format

local CasyncClient = class("asyncClient", CasyncBase)

function CasyncClient:_init_(beaver, hostFd, tPort, tmo)
    local fd = sockComm.connectSetup(tPort)
    self._tPort = tPort
    self._coWake = coroutine.running()
    self._status = 0  -- 0:disconnect, 1 connected, 2 connecting, 3 connect failed.

    CasyncBase._init_(self, beaver, fd, tmo)
    -- assert(self:_waitConnected(beaver, hostFd) == 0, "connect socket failed.")
    self._status = self:_waitConnected(beaver, hostFd)
    self._hostFd = hostFd
end

function CasyncClient:_del_()
    self:close()
end

function CasyncClient:status()
    return self._status
end

function CasyncClient:wake(co, v)
    local res, msg
    if coroutine.status(co) == "suspended" then
        res, msg = coroutine.resume(co, v)
        system.coReport(co, res, msg)
        return msg
    end
end

function CasyncClient:_waitConnected(beaver, fd)  -- this fd is server fd,
    local res = self._status
    if res == 1 then -- connect ok.
        return 1
    elseif res == 2 then -- connecting
        beaver:mod_fd(fd, -1)  -- mask io event, only close event is working.
        local w = coroutine.yield()
        beaver:mod_fd(fd, 0)  -- back host fd to read mode
        local t = type(w)
        if t == "number" then  -- 0 is ok
            if w == 1 then  -- refer to sockComm, 0 means connect ok.
                return 1
            end
            return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
        else
            -- print("wake from self.", t, w, w.ev_close, w.ev_in, w.ev_out)
            if w.ev_close == 1 then  -- wake from remote stream.
                return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
            else
                error(string.format("beaver report bug: fd: %d, in: %d, out: %d", w.fd, w.ev_in, w.ev_out))
            end
            return 0
        end
    else  -- 0 connect failed
        return res
    end
end

function CasyncClient:_waitData(stream)
    local beaver = self._beaver
    local coWake = self._co
    local selfFd = self._hostFd

    local status = self._status

    if status == 1 then -- connect ok.
        local res, msg
        local e

        local statCo = coroutine.status(coWake)
        if statCo == "suspended" then
            res, msg = coroutine.resume(coWake, stream)
            system.coReport(coWake, res, msg)
            beaver:mod_fd(selfFd, -1)  -- to block fd other event, mask io event, only close event is working.
            e = coroutine.yield()
            if type(e) == "cdata" then
                if e.ev_close == 1 and e.fd == selfFd then
                    return nil, "local socket closeed."
                else
                    error(string.format("beaver report bug: fd: %d, in: %d, out: %d", e.fd, e.ev_in, e.ev_out))
                end
            end
            beaver:mod_fd(selfFd, 0)  -- back to read mode
        elseif statCo == "normal" then    -- wake from http client.
            e = coroutine.yield(stream)
        else
            error(format("beaver report bug: co status: %s", statCo))
        end

        local t = type(e)
        if t ~= "nil" then
            return e
        else
            return nil, "read bad body."
        end
    else
        return nil, "not connected."
    end
end

function CasyncClient:close()
    if self._status > 0 then
        local e = c_type.new("native_event_t")
        e.ev_close = 1
        e.fd = self._fd
        self:_waitData(e)
        self._status = 0
    end
end

return CasyncClient
