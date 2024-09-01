require("eclass")

local system = require("common.system")
local sockComm = require("common.sockComm")
local CasyncBase = require("async.asyncBase")
local cffi = require("beavercffi")
local pystring = require("pystring")
local c_type, c_api = cffi.type, cffi.api

local class = class
local CasyncClient = class("asyncClient", CasyncBase)

local print = print
local type = type
local tostring = tostring
local format = string.format
local running = coroutine.running
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local liteAssert = system.liteAssert
local coReport = system.coReport
local startswith = pystring.startswith
local debugTraceback = debug.traceback
local error = error
local connectSetup = sockComm.connectSetup
local sockConnect = sockComm.connect
local cliSslHandshake = sockComm.cliSslHandshake

function CasyncClient:_init_(tReq, hostFd, tPort, tmo)
    local fd = connectSetup(tPort)
    self._tPort = tPort
    self._coWake = running()
    self._status = 0
    -- 0:disconnect, 1 connected, 2 connecting, 3 connect failed.

    if tReq.clients then  -- will auto release when close host client.
        tReq.clients[self] = true
    end

    local beaver = tReq.beaver
    self._hostFd = hostFd
    CasyncBase._init_(self, beaver, fd, tmo)
    if self:_waitConnected(beaver, hostFd) ~= 1 then  -- connect
        return
    end
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
        if t == "number" then  -- 1 is ok  wake from cliConnect function.
            if w == 1 then  -- refer to sockComm, 1 means connect ok.
                return 1
            end
            return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
        elseif t == "cdata" then
            -- print("wake from self.", t, w, w.ev_close, w.ev_in, w.ev_out)
            if w.ev_close == 1 then  -- wake from remote stream.
                return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
            else
                error(format("beaver report bug: fd: %d, in: %d, out: %d", w.fd, w.ev_in, w.ev_out))
            end
            return 3
        elseif t == "nil" then   -- wake from local stream close.
            return 3 -- 3 connect failed, refer to sockComm, 3 means connect failed.
        else
            error(format("beaver report bug: type: %s, %s", t, tostring(w)))
        end
    else  -- 0 connect failed
        return res
    end
end

local function proxyHandshake(beaver, fd, tPort)
    local host = tPort.host
    local req = format("CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n", host, host)

    local res = beaver:write(fd, req)
    if not res then
        return 3
    end

    local clear = beaver:timerWait(fd)
    local e = yield()
    clear()
    local t = type(e)
    if t == "nil" then  -- fd has closed.
        return 3
    elseif t == "number" then  -- timeout
        return 3
    elseif t == "cdata" then  -- has data to read
        if e.ev_close > 0 then   -- fd closed.
            return 3
        elseif e.ev_in > 0 then  -- has data to read
            res = beaver:read(fd, 256)
            if not res then
                return 3
            end
            if startswith(res, "HTTP/1.1 200") then
                return 1
            else
                return 3
            end
        else
            print("IO Error.")
        end
    else
        print(format("proxyHandshake, type: %s, unknown error., %s", t, tostring(e)))
    end
    return 3
end

function CasyncClient:cliConnect(fd)
    local beaver = self._beaver
    local stat, direct
    local tPort = self._tPort

    self._status = 2  -- connecting
    stat, direct = sockConnect(fd, tPort, beaver)  -- 

    if stat == 1 and tPort.ssl then
        if tPort.proxy then
            stat = proxyHandshake(beaver, fd, tPort)
            if stat == 1 then
                stat = cliSslHandshake(fd, beaver)
            end
        else
            stat = cliSslHandshake(fd, beaver)
        end
        direct = nil
    end

    self._status = stat  -- connected
    return stat, direct or self:wake(self._coWake, stat)  -- wake up to wake, set in asyncClient.
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
        if statCo == "suspended" then  -- wake from this client.
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
            self._status = 0
        elseif statCo == "dead" then
            error(format("beaver report bug: dead co status: %s", debugTraceback(coWake)))
        else
            error(format("beaver report bug: co status: %s", statCo))
        end
    else
        error(format("beaver report bug: status: %s", debugTraceback(coWake)))
    end
end

function CasyncClient:hold()  -- reuse this connect.
    return self:_waitData(0)
end

function CasyncClient:close()
    local stat = self._status
    if stat > 0 then
        self:_waitData(nil)
        liteAssert(self._status == 0, "close socket failed. " .. self._status .. debugTraceback(self._co))
    end
end

return CasyncClient
