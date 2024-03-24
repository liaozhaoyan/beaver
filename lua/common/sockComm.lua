---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/7 11:11 AM
---

local system = require("common.system")
local unistd = require("posix.unistd")
local psocket = require("posix.sys.socket")
local CasyncAccept = require("async.asyncAccept")
local workVar = require("module.workVar")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local format = string.format
local newSocket = psocket.socket
local connect = psocket.connect

local M = {}

local ip_pattern = "(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)"

local function match_ip(ip)
    local d1, d2, d3, d4 = ip:match(ip_pattern)
    if d1 and d2 and d3 and d4 then
        local num1, num2, num3, num4 = tonumber(d1), tonumber(d2), tonumber(d3), tonumber(d4)
        if num1 >= 0 and num1 <= 255 and num2 >= 0 and num2 <= 255 and num3 >= 0 and num3 <= 255 and num4 >= 0 and num4 <= 255 then
            return true
        end
    end
    return false
end

function M.getIp(host)
    local domain, ip
    if match_ip(host) then
        ip = host
    else
        domain, ip = workVar.dnsReq(host)
        assert(domain == host, "bad dns request.")
    end
    return ip
end

function M.setupSocket(conf)
    local res, fd, err, errno
    if conf.port then
        fd, err, errno = newSocket(psocket.AF_INET, psocket.SOCK_STREAM, 0)
        assert(fd, err)
        local tPort = {family=psocket.AF_INET, addr=conf.bind, port=conf.port}
        res = c_api.setsockopt_reuse_port(fd)
        assert(res == 0, format("reuse port failed, return %d.", res))
        res, err, errno = psocket.bind(fd, tPort)
        assert(res, err)
    elseif conf.uniSock then
        unistd.unlink(conf.uniSock)
        fd, err, errno = newSocket(psocket.AF_UNIX, psocket.SOCK_STREAM, 0)
        assert(fd, err)
        local tPort = {family=psocket.AF_UNIX, path=conf.uniSock, addr="", port=0}
        res, err, errno = psocket.bind(fd, tPort)
        assert(res, err)
    else
        error("bad bind mode.")
    end
    local backlog = conf.backlog or 100
    res, err, errno = psocket.listen(fd, backlog)
    assert(res, err)
    return fd
end

function M.connectSetup(tPort)
    local fd, err, errno
    if tPort.port then
        fd, err, errno = newSocket(psocket.AF_INET, psocket.SOCK_STREAM, 0)
        assert(fd, err)
    elseif tPort.path then
        unistd.unlink(tPort.path)
        fd, err, errno = newSocket(psocket.AF_UNIX, psocket.SOCK_STREAM, 0)
        assert(fd, err)
    else
        error("bad connect mode.")
    end
    return fd
end

local function tryConnect(fd, tConn)
    local res, err, errno

    res, err, errno = connect(fd, tConn)
    if not res then
        if errno == 115 then  -- need to wait.
            return 2  -- refer to aysync.asyncClient _init_ 2 connecting
        else
            error(format("socket connect %s, %d failed, report:%d, %s", tConn.addr, tConn.port, errno, err))
            return
        end
    else
        return res
    end
end

function M.connect(fd, tPort, beaver)
    local res = tryConnect(fd, tPort)
    if res == 2 then -- 2 means connecting  refer to aysync.asyncClient _init_
        beaver:mod_fd(fd, 1)  -- modify fd to writeable
        local connected = false
        repeat
            local e = coroutine.yield()
            if type(e) == "nil" then
                return 3 -- connected failed  refer to aysync.asyncClient _init_
            elseif e.ev_out > 0 then
                if c_api.check_connected(fd) == 0 then
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

local ChttpInst = require("http.httpInst")

local instTable = {
    httpServer = function(conf)
        local app = require("app." .. conf.entry)
        local inst = ChttpInst.new()
        app.new(inst, conf)
        return inst
    end,
}

local function setupInst(conf)
    local func = instTable[conf.func]
    if func then
        return func(conf)
    end
    return nil
end

local function acceptServer(obj, conf, beaver, bfd)
    workVar.bindAdd(conf.func, bfd, coroutine.running())
    local inst = setupInst(conf)
    CasyncAccept.new(beaver, bfd, -1)
    while true do
        local nfd, addr = coroutine.yield()
        obj.new(beaver, nfd, bfd, addr, conf, inst)
    end
end

function M.acceptSetup(obj, beaver, conf)
    assert(conf.mode == "TCP", "bad accept mode: " .. conf.mode)
    local fd = M.setupSocket(conf)
    local co = coroutine.create(acceptServer)
    local res, msg = coroutine.resume(co, obj, conf, beaver, fd)
    system.coReport(co, res, msg)
end

return M