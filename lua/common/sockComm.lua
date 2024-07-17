---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/7 11:11 AM
---

local require = require
local system = require("common.system")
local unistd = require("posix.unistd")
local psocket = require("posix.sys.socket")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local format = string.format
local type = type
local print = print
local error = error
local yield = coroutine.yield
local liteAssert = system.liteAssert
local b_socket = c_api.b_socket
local b_listen = c_api.b_listen
local b_bind_ip = c_api.b_bind_ip
local b_bind_uds = c_api.b_bind_uds
local b_connect_ip = c_api.b_connect_ip
local b_connect_uds = c_api.b_connect_uds
local b_close = c_api.b_close
local ssl_connect_pre = c_api.ssl_connect_pre
local ssl_accept_pre = c_api.ssl_accept_pre
local ssl_handshake = c_api.ssl_handshake
local ssl_del = c_api.ssl_del
local vsock_socket = c_api.vsock_socket
local vsock_connect = c_api.vsock_connect
local vsock_bind = c_api.vsock_bind
local setsockopt_reuse_port = c_api.setsockopt_reuse_port
local check_connected = c_api.check_connected
local NULL = c_type.NULL

local mt = {}

local lpeg = require('lpeg')
local P, R = lpeg.P, lpeg.R

local digit19 = R("19")
local digit = R("09")
local double_digit = digit19 * digit
local triple_digit_1 = P"1" * digit * digit
local triple_digit_2 = P"2" * R("04") * digit
local triple_digit_3 = P"25" * R("05")
local number = triple_digit_3 + triple_digit_2 + triple_digit_1 + double_digit + digit19 + P"0"
local dot = P"."
local ipv4 = number * dot * number * dot * number * dot * number

function mt.isIPv4(ip)
    if ipv4:match(ip) then
        return true
    else
        return false
    end
end

function mt.setupSocket(conf)
    local res, fd
    if conf.port then
        fd = b_socket(psocket.AF_INET, psocket.SOCK_STREAM, 0)
        liteAssert(fd > 0, format("b_socket failed, return %d.", fd))
        res = setsockopt_reuse_port(fd)
        liteAssert(res == 0, format("reuse port failed, return %d.", res))
        res = b_bind_ip(fd, conf.bind, conf.port)
        liteAssert(res == 0, format("b_bind_ip failed, return %d.", res))
    elseif conf.uniSock then
        unistd.unlink(conf.uniSock)
        fd = b_socket(psocket.AF_UNIX, psocket.SOCK_STREAM, 0)
        liteAssert(fd > 0, format("b_socket failed, return %d.", fd))
        res = b_bind_uds(fd, conf.uniSock)
        liteAssert(res == 0, format("b_bind_uds failed, return %d.", res))
    elseif conf.vsock then
        fd = vsock_socket(psocket.SOCK_STREAM, 0)
        if fd < 0 then
            error(format("vsock_socket failed, return %d.", fd))
        end
        res = vsock_bind(fd, conf.vsock.cid, conf.vsock.port)
        liteAssert(res == 0, format("vsock_bind failed, return %d.", res))
    else
        error("bad bind mode.")
    end
    local backlog = conf.backlog or 100
    res = b_listen(fd, backlog)
    liteAssert(res == 0, format("b_listen failed, return %d.", res))
    return fd
end

function mt.connectSetup(tPort)
    local fd
    if tPort.port then
        fd = b_socket(psocket.AF_INET, psocket.SOCK_STREAM, 0)
        liteAssert(fd > 0, format("b_socket failed, return %d.", fd))
    elseif tPort.path then
        fd = b_socket(psocket.AF_UNIX, psocket.SOCK_STREAM, 0)
        liteAssert(fd > 0, format("b_socket failed, return %d.", fd))
        tPort.family = psocket.AF_UNIX
    elseif tPort.vsock then
        fd = vsock_socket(psocket.SOCK_STREAM, 0)
        liteAssert(fd > 0, format("vsock_socket failed, return %d.", fd))
    else
        error("bad connect mode.")
    end
    return fd
end

local function tryConnect(fd, tPort)
    local res, errno

    if tPort.port then
        res = b_connect_ip(fd, tPort.addr, tPort.port)
        if res > 0 then   -- connect not ready.
            errno = res
            res = nil
        end
    elseif tPort.path then
        res = b_connect_uds(fd, tPort.path)
        if res > 0 then   -- connect not ready.
            errno = res
            res = nil
        end
        tPort.family = psocket.AF_UNIX
    elseif tPort.vsock then
        res = vsock_connect(fd, tPort.vsock.cid, tPort.vsock.port)
        if res > 0 then   -- connect not ready.
            errno = res
            res = nil
        end
    else
        error("bad connect mode.")
    end

    if not res then
        if errno == 115 then  -- need to wait.
            return 2  -- refer to aysync.asyncClient _init_ 2 connecting
        else  -- connect failed
            -- print(format("socket connect failed, report:%d", errno))
            return 3 -- connected failed
        end
    else
        return 1   -- 1 means connected
    end
end

function mt.connect(fd, tPort, beaver)
    local res = tryConnect(fd, tPort)
    if res == 2 then -- 2 means connecting  refer to aysync.asyncClient _init_
        beaver:mod_fd(fd, 1)  -- modify fd to writeable
        local connected = false
        repeat
            local e = yield()
            if type(e) == "nil" then
                return 3 -- connected failed  refer to aysync.asyncClient _init_
            elseif type(e) ~= "cdata" then
                print("connected failed, unexpected event.", type(e), e)
                return 3 -- connected failed, unexpected event
            elseif e.ev_out > 0 then
                if check_connected(fd) == 0 then
                    connected = true
                    beaver:mod_fd(fd, 0)   -- modify fd to readonly
                    return 1  -- connected success  refer to aysync.asyncClient _init_
                else
                    return 3
                end
            elseif e.ev_close > 0 then
                return 3
            end
        until connected
    end
    return res
end

local function handshakeYield()
    local e = yield()  -- if close fd, will resume nil
    if e == nil or e.ev_close > 0 then
        return true
    end
    return false
end

function mt.cliSslHandshake(fd, beaver)
    local handler = ssl_connect_pre(fd, NULL)
    if handler == nil then
        return 3
    end
    local ret
    repeat
        ret = ssl_handshake(handler)
        if ret == 1 then
            beaver:mod_fd(fd, 1)
            if handshakeYield() then
                ret = -1
            end
        elseif ret == 2 then
            beaver:mod_fd(fd, 0)
            if handshakeYield() then
                ret = -1
            end
        end
    until (ret <= 0)
    beaver:mod_fd(fd, 0)
    if ret < 0 then
        ssl_del(handler)
        handler = nil
        return 3
    else
        beaver:ssl_add(fd, handler)
        return 1
    end
end

function mt.srvSslHandshake(beaver, fd, ctx)
    local handler = ssl_accept_pre(fd, ctx)
    if handler == nil then
        return 3
    end
    local ret
    repeat
        ret = ssl_handshake(handler)
        if ret == 1 then
            beaver:mod_fd(fd, 1)
            if handshakeYield() then
                ret = -1
            end
        elseif ret == 2 then
            beaver:mod_fd(fd, 0)
            if handshakeYield() then
                ret = -1
            end
        end
    until (ret <= 0)
    beaver:mod_fd(fd, 0)
    if ret < 0 then
        ssl_del(handler)
        handler = nil
        return 3
    else
        beaver:ssl_add(fd, handler)
        return 1
    end
end

return mt