---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/19 12:26 AM
---

require("eclass")

local psocket = require("posix.sys.socket")
local CasyncClient = require("async.asyncClient")
local workVar = require("module.workVar")
local sockComm = require("common.sockComm")
local httpRead = require("http.httpRead")
local httpComm = require("http.httpComm")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local format = string.format

local httpConnectTmo = 10

local ChttpReq = class("request", CasyncClient)

function ChttpReq:_init_(tReq, host, port, tmo, proxy, maxLen)
    self._domain = host
    local ip

    if proxy then
        ip, port = proxy.ip, proxy.port
    else
        ip, port = workVar.getIp(host), port or 80
    end

    tmo = tmo or 60
    self._maxLen = maxLen or 2 * 1024 * 1024

    local tPort = {family=psocket.AF_INET, addr=ip, port=port}
    CasyncClient._init_(self, tReq.beaver, tReq.fd, tPort, tmo)
end

function ChttpReq:_setup(fd, tmo)
    local beaver = self._beaver
    local co = self._coWake
    local maxLen = self._maxLen
    local status, res
    local e

    workVar.connectAdd("httpReq", fd, coroutine.running())

    status, e = self:cliConnect(fd, tmo)

    while status == 1 do
        if not e then
            e = coroutine.yield()
        end
        local t = type(e)
        if t == "string" then -- has data to send
            beaver:co_set_tmo(fd, tmo)
            res = beaver:write(fd, e)
            if not res then
                break
            end
            e = nil
            beaver:co_set_tmo(fd, -1)
        elseif t == "nil" then  -- host closed
            self:wake(co, nil)
            break
        else  -- read event.
            if e.ev_close > 0 then
                break
            elseif e.ev_in > 0 then
                local fread = beaver:reads(fd, maxLen)
                local tRes = httpRead.clientRead(fread)
                e = self:wake(co, tRes)
                t = type(e)
                if t == "cdata" then -->upstream need to close.
                    assert(e.ev_close > 0)
                    self:wake(co, nil)  -->let upstream to do next working.
                    break
                elseif t == "number" then  -->upstream reuse connect
                    e = nil
                end
            else
                print("IO Error.")
                break
            end
        end
    end

    self._status = 0  -- closed
    self:stop()
    c_api.b_close(fd)
    workVar.connectDel("httpReq", fd)
end

local function setupHeader(headers)
    headers = headers or {}
    if not headers.Accept then
        headers.Accept = "text/*, application/json, image/*, application/octet-stream"
    end
    return headers
end

local function checkKeepAlive(res)
    if not res then -- nil, bad response
        return false
    end

    if res.headers and res.headers.connection then
        if res.headers.connection == "close" then
            return false
        end
    end
    return true
end

local commPackClientFrame = httpComm.packClientFrame
function ChttpReq:_req(verb, uri, headers, body, reuse)
    if self._status ~= 1 then
        return {body = format("connected %s status is %d, should be 1.", self._domain, self._status), 
                code = 500}
    end
    headers = headers or {}
    headers.Host = self._domain
    local res = {
        url = uri,
        method = verb,
        headers = setupHeader(headers),
        body = body or "",
    }
    local stream = commPackClientFrame(res)
    local res, msg = self:_waitData(stream)
    assert(res, msg)
    if type(res) ~= "table" then
        -- closed by remote server.
        return nil
    end
    if not reuse or not checkKeepAlive(res) then
        self:close()
    end
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
