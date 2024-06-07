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

local print = print
local type = type
local format = string.format
local liteAssert = system.liteAssert
local coReport = system.coReport
local create = coroutine.create
local running = coroutine.running
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local jencode = cjson.encode

local var = {
    -- for multi delay, loop >= 1
    periodWakeCo = {},   -- multi delayed,
    periodWakeId = 1,    -- index
}

function M.setPipeOut(coOut)
    var.coOut = coOut
end

local function sendCoOut(stream)
    local res, msg = resume(var.coOut, stream)
    coReport(var.coOut, res, msg)
    if msg == false then  -- send buffer full, wait for write wake.
        print("neend to sleep.")
        yield()
        print("wake from sleep.")
    end
end

local function regThreadId(arg)
    var.id = arg.id
    local func = {
        func = "workerReg",
        arg = {
            id = arg.id
        }
    }

    sendCoOut(jencode(func))

    if var.setupCb then
        local call = var.setupCb.func
        local args = var.setupCb.args
        call(args)
        var.setupCb = nil  -- clear after call.
    end
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
        var.periodWakeCo[coId] = nil  -- dead.
    end
end

local funcTable = {
    regThreadId = function(arg) return regThreadId(arg)  end,
    echoWake    = function(arg) return echoWake(arg)  end,
}

function M.call(arg)
    return funcTable[arg.func](arg.arg)
end

function M.setVar(beaver, conf, yaml)
    var.thread = {
        beaver = beaver,
        conf = conf,
        yaml = yaml
    }
end

function M.getVar()
    return var.thread
end

function M.setCb(func, args)
    var.setupCb = {
        func = func,
        args = args
    }
end

local function periodWakeGetId()
    local ret = var.periodWakeId
    var.periodWakeCo[ret] = coroutine.running()
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
    sendCoOut(jencode(func))
    return yield()
end

function M.msleep(ms)
    if ms < 1 then
        return
    end
    return M.periodWake(ms, 1)
end

local function acceptServer(obj, conf, beaver, bfd, bindAdd)
    if bindAdd then
        bindAdd(conf.func, bfd, running())
    end
    CasyncAccept.new(beaver, bfd, -1)
    while true do
        local nfd, addr = yield()
        obj.new(beaver, nfd, bfd, addr, conf)
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
