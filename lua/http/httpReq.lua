---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/19 12:26 AM
---

local require = require
require("eclass")

local psocket = require("posix.sys.socket")
local posix = require("posix")
local CasyncClient = require("async.asyncClient")
local workVar = require("module.workVar")
local parseUrl = require("common.parseUrl")
local httpRead = require("http.httpRead")
local httpComm = require("http.httpComm")
local stat = posix.sys.stat

local format = string.format
local type = type
local print = print
local tonumber = tonumber
local tostring = tostring
local running = coroutine.running
local yield = coroutine.yield
local error = error
local assert = assert
local fstat = stat.stat
local clientRead = httpRead.clientRead
local getIp = workVar.getIp
local parse = parseUrl.parse
local isSsl = parseUrl.isSsl

local httpConnectTmo = 10

local class = class
local ChttpReq = class("request", CasyncClient)

local function setupUrl(host, port, proxy)
    local scheme, domain, _port = parse(host)
    local ip
    local connectPort
    local isProxy

    if not domain then
        print(format("host: %s, not support.", tostring(host)))
        return nil
    end

    if not port then
        if _port then
            port = tonumber(_port)
        else
            if scheme == "https" then
                port = 443
            else
                port = 80
            end
        end
    end

    if proxy then
        ip, connectPort = proxy.ip, proxy.port
        isProxy = true
    else
        ip, connectPort = getIp(domain), port
        isProxy = false
    end
    local Host = format("%s:%d", domain, port)
    local tPort = {family=psocket.AF_INET, addr=ip, port=connectPort, ssl=isSsl(scheme), proxy=isProxy, host=Host}
    return Host, tPort
end

function ChttpReq:_init_(tReq, host, port, tmo, proxy, maxLen)
    local tPort
    local host_t = type(host)

    if host_t == "table" then   -- is a table , may uds or kata socket.
        local path
        if host.path then
            path = host.path
            if not fstat(path) then
                self._status = 0
                return
            end
            self._domain = path
        else
            error("not support socket type.")
        end

        if host.kata and port then
           self._kataPort = port
        end
        tPort = {family=psocket.AF_UNIX, path=host.path}
    elseif host_t == "string" then
        self._domain, tPort = setupUrl(host, port, proxy)
        if not self._domain then
            self._status = 0
            return
        end
    else
        self._status = 0
        return 0
    end

    tmo = tmo or 60
    self._maxLen = maxLen or 2 * 1024 * 1024
    self._reuse = false   -- not reuse connect in default condition.

    CasyncClient._init_(self, tReq, tReq.fd, tPort, tmo)
end

function ChttpReq:_setup(fd, tmo)
    local beaver = self._beaver
    local co = self._coWake
    local maxLen = self._maxLen
    local status, res
    local e

    beaver:co_set_tmo(fd, tmo)
    workVar.connectAdd("httpReq", fd, running())

    status, e = self:cliConnect(fd, tmo)

    if status == 1 and self._kataPort then
        status = self:_connKata(fd, beaver)
        self._status = status  -- 当期状况可能会去唤醒 等待co，co可能会在get等方法中访问self._status状态，必须要提前设置
        if status == 1 then
            e = self:wake(co, true) -- 连接成功, 接下来的数据将会通过co 传递过来。
        else
            self:wake(co, false)  -- 连接失败
        end
    end

    if status == 1 and e == nil then -- host closed
        self._status = 0
        self:wake(co, nil)
    end
    if type(e) == "boolean" then  -- for unix socket connect direct may return boolean true.
        e = nil
    end

    local clear
    while status == 1 do
        if not e then
            e = yield()
        end
        local _ = clear and clear()
        local t = type(e)
        if t == "string" then -- has data to send
            local msg
            res, msg = beaver:write(fd, e)
            if not res then
                print("http write error.", msg)
                self._status = 0
                self:wake(co, nil)
                break
            end
            clear = beaver:timerWait(fd)
            e = nil  -- wait next yeild.
        elseif t == "nil" then  -- host closed
            self:wake(co, nil)
            break
        elseif t == "number" then --> request time out.
            if e > 0 then
                self._status = 0
                self:wake(co, nil)
                break
            end
            e = nil  -- 0 mean need to reuse connect
        elseif t == "cdata" then  -- read event.
            local ev_in, ev_close = e.ev_in, e.ev_close
            if ev_in > 0 then
                clear = nil -- clear timerWait call back.
                local fread = beaver:reads(fd, maxLen, tmo)
                local tRes, msg = clientRead(fread, tmo / 2)
                if not tRes then
                    -- print("get remote closed.", msg)
                    self._status = 0
                    self:wake(co, nil)  --> wake up upstream co to close.
                    break
                end

                local r = self:wake(co, tRes)
                if ev_close > 0 then   -->remote server closed
                    self._status = 0
                    self:wake(co, nil)
                    break
                end

                e = r
                t = type(e)
                if t == "nil" then -->upstream need to close.
                    self._status = 0
                    self:wake(co, nil)  -->let upstream to do next working.
                    break
                elseif t == "number" then  -->upstream reuse connect
                    if e > 0 then -- e > 0 means timeout.
                        self._status = 0
                        self:wake(co, nil)
                        break
                    end
                    e = nil
                elseif t ~= "string" then   --> string mean has next data to send
                    error(format("ChttpReq type: %s, unknown error.", t))
                end
            elseif ev_close > 0 then
                self._status = 0
                self:wake(co, nil)
                break
            else
                print("IO Error.")
                self._status = 0
                break
            end
        else
            error(format("ChttpReq type: %s, not support, unknown error.", t))
        end
    end

    self._status = 0  -- closed
    self:stop()
    workVar.connectDel("httpReq", fd)
end

function ChttpReq:_connKata(fd, beaver)
    local port = self._kataPort
    local res = beaver:write(fd, format("connect %d\n", port))
    if not res then
        return 3  -- need close.
    end
    
    local clear = beaver:timerWait(fd)
    local e = yield()
    clear()
    local t = type(e)
    if t == "nil" then  -- fd has closed.
        print("kata fd has closed.")
        return 3
    elseif t == "number" then
        print("kata connect timeout.")
        return 3
    elseif t == "cdata" then  -- has data to read
        if e.ev_close > 0 then   -- fd closed.
            return 3
        elseif e.ev_in > 0 then  -- has data to read
            res = beaver:read(fd, 128)
            if not res then
                return 3
            end
            return 1
        else
            print("IO Error.")
        end
    else
        print(format("type: %s, unknown error., %s", t, tostring(e)))
    end
    return 3
end

function ChttpReq:kataReady()
    local ok = yield()  --only kata need to wait
    return ok
end

function ChttpReq:reuse(resue)
    self._reuse = resue
end

local function setupHeader(headers)
    headers = headers or {}
    if not headers.Accept then
        headers.Accept = "text/*, application/json, image/*, application/octet-stream"
    end
    return headers
end

local commPackClientFrame = httpComm.packClientFrame
function ChttpReq:_req(verb, uri, headers, body, reuse)
    if self._status ~= 1 then
        return {body = format("connected %s status is %d, should be 1.", self._domain, self._status), 
                code = 500}
    end
    headers = headers or {}
    headers.Host = self._domain
    local sendTable = {
        url = uri,
        method = verb,
        headers = setupHeader(headers),
        body = body or "",
    }
    local stream = commPackClientFrame(sendTable)
    local res, msg = self:_waitData(stream)
    if type(res) ~= "table" then
        -- closed by remote server.
        self:close()
        return nil
    end
    if reuse or self._reuse then
        return res
    end
    self:close()
    return res
end

function ChttpReq:post(uri, headers, body, reuse)
    return self:_req("POST", uri, headers, body, reuse)
end

function ChttpReq:get(uri, headers, body, reuse)
    return self:_req("GET", uri, headers, body, reuse)
end

function ChttpReq:put(uri, headers, body, reuse)
    return self:_req("PUT", uri, headers, body, reuse)
end

function ChttpReq:delete(uri, headers, body, reuse)
    return self:_req("DELETE", uri, headers, body, reuse)
end

return ChttpReq
