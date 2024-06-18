require("eclass")

local system = require("common.system")
local sockComm = require("common.sockComm")
local CasyncBase = require("async.asyncBase")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local class = class
local CasyncClient = class("asyncClient", CasyncBase)

local type = type
local format = string.format
local c_new = c_type.new
local running = coroutine.running
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local liteAssert = system.liteAssert
local coReport = system.coReport
local error = error

function CasyncClient:_init_(tReq, hostFd, tPort, tmo)
    local fd = sockComm.connectSetup(tPort)
    self._tPort = tPort
    self._coWake = running()
    self._status = 0
    -- 0:disconnect, 1 connected, 2 connecting, 3 connect failed.

    
    if tReq.clients then  -- will auto release when close host client.
        tReq.clients[self] = true
    end

    local beaver = tReq.beaver
    CasyncBase._init_(self, beaver, fd, tmo)
    self._status = self:_waitConnected(beaver, hostFd)
    self._hostFd = hostFd
end

function CasyncClient:status()
    return self._status
end

function CasyncClient:wake(co, v)
    local res, msg
    if status(co) == "suspended" then
        res, msg = resume(co, v)
        coReport(co, res, msg)
        return msg
    end
end

function CasyncClient:_waitConnected(beaver, hostFd)  -- this fd is server fd,
    local res = self._status
    if res == 1 then -- connect ok.
        return 1
    elseif res == 2 then -- connecting
        local w
        if hostFd then
            beaver:mod_fd(hostFd, -1)  -- mask io event, only close event is working.
            w = yield()
            beaver:mod_fd(hostFd, 0)  -- back host fd to read mode
        else
            w = yield()
        end
        
        local t = type(w)
        if t == "number" then  -- 0 is ok
            if w == 1 then  -- refer to sockComm, 1 means connect ok.
                return 1
            end
            return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
        else
            -- print("wake from self.", t, w, w.ev_close, w.ev_in, w.ev_out)
            if w.ev_close == 1 then  -- wake from remote stream.
                return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
            else
                error(format("beaver report bug: fd: %d, in: %d, out: %d", w.fd, w.ev_in, w.ev_out))
            end
            return 0
        end
    else  -- 0 connect failed
        return res
    end
end

function CasyncClient:cliConnect(fd, tmo)
    local beaver = self._beaver
    local stat

    self._status = 2  -- connecting
    beaver:co_set_tmo(fd, tmo)  -- set connect timeout
    stat = sockComm.connect(fd, self._tPort, beaver)  -- 
    beaver:co_set_tmo(fd, -1)   -- back
    self._status = stat  -- connected
    return stat, self:wake(self._coWake, stat)  -- wake up to wake, set in asyncClient.
end

function CasyncClient:_waitData(stream)
    local beaver = self._beaver
    local coWake = self._co
    local selfFd = self._hostFd

    local stat = self._status

    if stat == 1 then -- connect ok.
        local res, msg
        local e

        local statCo = status(coWake)
        if statCo == "suspended" then
            res, msg = resume(coWake, stream)
            coReport(coWake, res, msg)

            if type(stream) == "nil" then  -- for host fd close event.
                return nil
            end

            if selfFd then
                beaver:mod_fd(selfFd, -1)  -- to block fd other event, mask io event, only close event is working. 
                e = yield()
                if type(e) == "cdata" then
                    if e.ev_close == 1 and e.fd == selfFd then
                        return nil, "local socket closeed."
                    else
                        error(format("beaver report bug: fd: %d, in: %d, out: %d", e.fd, e.ev_in, e.ev_out))
                    end
                end
                beaver:mod_fd(selfFd, 0)  -- back to read mode
            else
                e = yield()
            end
        elseif statCo == "normal" then    -- wake from http client.
            e = yield(stream)
            if stream == nil then
                return nil
            end
        else
            error(format("beaver report bug: co status: %s", statCo))
        end

        local t = type(e)
        if t ~= "nil" then
            return e
        else
            return nil, "read bad body."
        end
    elseif stat == 2 or stat == 3 then -- connecting
        local res, msg
        liteAssert(type(stream) == "nil", "stream should be a nil close event.")
        local statCo = status(coWake)
        if statCo == "suspended" then
            res, msg = resume(coWake, stream)
            coReport(coWake, res, msg)
            return nil, "connecting interrupt."
        elseif statCo == "normal" then    -- wake from http client.
            yield(nil)
        else
            error(format("beaver report bug: co status: %s", statCo))
        end
    else
        return nil, "not connected."
    end
end

function CasyncClient:close()
    local stat = self._status
    if stat > 0 then
        self:_waitData(nil)
        liteAssert(self._status == 0, "close socket failed. " .. self._status)
    end
end

return CasyncClient
