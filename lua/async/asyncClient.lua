require("eclass")

local system = require("common.system")
local sockComm = require("module.sockComm")
local CasyncBase = require("async.asyncBase")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local CasyncClient = class("asyncClient", CasyncBase)

function CasyncClient:_init_(beaver, hostFd, tPort, tmo)
    local fd = sockComm.connectSetup(tPort)
    self._tPort = tPort
    self._coWake = coroutine.running()
    self._status = 0  -- 0:disconnect, 1 connected, 2 connecting

    CasyncBase._init_(self, beaver, fd, tmo)
    assert(self:_waitConnected(beaver, hostFd) == 0, "connect socket failed.")
    self._hostFd = hostFd
end

function CasyncClient:_del_()
    self:close()
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
    if res == 0 then -- connect ok.
        return 0
    elseif res == 2 then -- connecting
        beaver:mod_fd(fd, -1)  -- mask io event, only close event is working.
        local w = coroutine.yield()
        beaver:mod_fd(fd, 0)  -- back host fd to read mode
        local t = type(w)
        if t == "number" then  -- 0 is ok
            return w
        else
            print("wake from self.", t, w, w.ev_close, w.ev_in, w.ev_out)
            return 1
        end
    else  -- 1 connect failed
        return 1
    end
end

function CasyncClient:_waitData(stream)
    local beaver = self._beaver
    local coWake = self._co
    local selfFd = self._hostFd

    local status = self._status

    if status == 0 then -- connect ok.
        local res, msg
        local e

        local statCo = coroutine.status(coWake)
        if statCo == "suspended" then
            res, msg = coroutine.resume(coWake, stream)
            system.coReport(coWake, res, msg)
            beaver:mod_fd(selfFd, -1)  -- to block fd other event, mask io event, only close event is working.
            e = coroutine.yield()
            beaver:mod_fd(selfFd, 0)  -- back to read mode
        elseif statCo == "normal" then    -- wake from http client.
            e = coroutine.yield(stream)
        else
            return nil
        end

        local t = type(e)
        if t ~= "nil" then
            return e
        else
            return nil
        end
    else
        return nil
    end
end

function CasyncClient:close()
    if self._status ~= 1 then
        local e = c_type.new("native_event_t")
        e.ev_close = 1
        e.fd = self._fd
        self:_waitData(e)
    end
end

return CasyncClient
