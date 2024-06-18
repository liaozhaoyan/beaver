---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/6 11:39 AM
---

local M = {}
local require = require
local system = require("common.system")
local CasyncAccept = require("async.asyncAccept")
local sockComm = require("common.sockComm")
local cjson = require("cjson.safe")

local type = type
local pairs = pairs
local error = error
local format = string.format
local liteAssert = system.liteAssert
local coReport = system.coReport
local isIPv4 = sockComm.isIPv4
local create = coroutine.create
local running = coroutine.running
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local jencode = cjson.encode

local var = {
    -- for server module manage.
    pingpong = {},
    dnsReq = {},
    upstream = {},
    httpServer = {},

    -- for connect module manage
    httpReq = {},

    -- for redis client
    redis = {},

    -- for dns manager
    dnsWait = {},   -- just for dns.
    dnsId  = 1,     -- dns request co id,

    -- for multi delay, loop >= 1
    periodWakeCo = {},   -- multi delayed,
    periodWakeId = 1,    -- index
}

function M.getIp(host)
    local domain, ip
    if isIPv4(host) then
        ip = host
    else
        domain, ip = M.dnsReq(host)
        if not ip then
            return nil, format("bad dns: host %s, domain %s", host, domain)
        end
    end
    return ip
end

function M.workerSetPipeOut(coOut)
    var.coOut = coOut
end

local function regThreadId(arg)
    var.id = arg.id
    local func = {
        func = "workerReg",
        arg = {
            id = arg.id
        }
    }

    local res, msg = resume(var.coOut, jencode(func))
    coReport(var.coOut, res, msg)

    if var.setupCb then
        local call = var.setupCb.func
        local args = var.setupCb.args
        call(args)
        var.setupCb = nil  -- clear after call.
    end
end

local function echoDns(arg)
    local coId = arg.coId
    local co = var.dnsWait[coId]

    if status(co) == "suspended" then
        local res, msg = resume(co, arg.domain, arg.ip)
        coReport(co, res, msg)
    end
    var.dnsWait[coId] = nil   -- free wait.
end

local function echoWake(arg)
    local res, msg
    local coId = arg.coId
    local co = var.periodWakeCo[coId]

    if type(co) == "thread" and status(co) == "suspended" then  -- co may set to nil
        res, msg = resume(co, arg.period)  -- wake to M.periodWake
        coReport(co, res, msg)
        if arg.loop == 0 then
            var.periodWakeCo[coId] = nil   -- free wait.
        end
    else
        var.periodWakeCo[coId] = nil   -- dead.
    end
end

local funcTable = {
    regThreadId = function(arg) return regThreadId(arg)  end,
    echoDns     = function(arg) return echoDns(arg)  end,
    echoWake    = function(arg) return echoWake(arg)  end,
}

function M.call(arg)
    return funcTable[arg.func](arg.arg)
end

function M.workerSetVar(beaver, conf, yaml)
    var.thread = {
        beaver = beaver,
        conf = conf,
        yaml = yaml
    }
end

function M.workerGetVar()
    return var.thread
end

function M.bindAdd(m, fd, co)
    liteAssert(not var[m][fd], format("%s bind socket is already in use.", m))
    var[m][fd] = {
        co = co,
        addrs = {},
        cos = {}
    }
end

function M.clientAdd(m, bfd, fd, co, addr)
    liteAssert(not var[m][bfd].cos[fd], format("%s work socket is already in use.", m))
    var[m][bfd].cos[fd] = co
    var[m][bfd].addrs[fd] = addr
end

function M.clientDel(m, fd)
    for _, m in pairs(var[m]) do
        for i, _ in pairs(m.cos) do
            if fd == i then
                m.addrs[i] = nil
                m.cos[i] = nil
                return
            end
        end
    end
    system.dumps(var[m])
    error(format("fd: %d is not register.", fd))
end

function M.connectAdd(m, fd, co)
    liteAssert(not var[m][fd], format("%s connect socket is already working.", m))
    var[m][fd] = co
end

function M.connectDel(m, fd)
    liteAssert(var[m][fd], format("%s connect socket is not working.", m))
    var[m][fd] = nil
end

local function dnsGetCoId()
    local ret = var.dnsId
    var.dnsWait[ret] = running()
    var.dnsId = var.dnsId + 1
    return ret
end

function M.dnsReq(domain)
    local func = {
        func = "reqDns",
        arg = {
            id = var.id,
            domain = domain,
            coId = dnsGetCoId()
        }
    }

    local res, msg = resume(var.coOut, cjson.encode(func))
    coReport(var.coOut, res, msg)
    local domain, ip = yield()
    return domain, ip
end

local function periodWakeGetId()
    local ret = var.periodWakeId
    var.periodWakeCo[ret] = running()
    var.periodWakeId = var.periodWakeId + 1
    return ret
end

function M.periodWake(period, loop)
    liteAssert(period >= 1, "period arg should greater than 1.")
    liteAssert(loop >= 1, "loop should greater than 1.")
    local func = {
        func = "reqPeriodWake",
        arg = {
            id = var.id,
            coId = periodWakeGetId(),
            period = period,
            loop = loop,
        }
    }

    local res, msg = resume(var.coOut, jencode(func))
    coReport(var.coOut, res, msg)
    return yield()  -- will return loop time, wake from echoWake function.
end

function M.msleep(ms)
    if ms < 1 then
        return
    end
    return M.periodWake(ms, 1)
end

function M.setCb(func, args)
    var.setupCb = {
        func = func,
        args = args
    }
end



local ChttpInst = require("http.httpInst")

local instTable = {
    httpServer = function(conf)
        local app = require(format("app.%s", conf.entry))
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

local function acceptServer(obj, conf, beaver, bfd, bindAdd)
    if bindAdd then
        bindAdd(conf.func, bfd, running())
    end
    local inst = setupInst(conf)
    CasyncAccept.new(beaver, bfd, -1)
    while true do
        local nfd, addr = yield()
        obj.new(beaver, nfd, bfd, addr, conf, inst)
    end
end

function M.acceptSetup(obj, beaver, conf, bindAdd)
    liteAssert(conf.mode == "TCP", format("bad accept mode: %s", conf.mode))
    local fd = sockComm.setupSocket(conf)
    local co = create(acceptServer)
    local res, msg = resume(co, obj, conf, beaver, fd, bindAdd)
    coReport(co, res, msg)
end

return M