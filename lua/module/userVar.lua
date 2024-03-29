---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/6 11:39 AM
---

local M = {}
local system = require("common.system")

local cjson = require("cjson.safe")

local var = {
    -- for multi delay, loop >= 1
    periodWakeCo = {},   -- multi delayed,
    periodWakeId = 1,    -- index
}

function M.setPipeOut(coOut)
    var.coOut = coOut
end

local function sendCoOut(stream)
    local res, msg = coroutine.resume(var.coOut, stream)
    system.coReport(var.coOut, res, msg)
    if msg == false then  -- send buffer full, wait for write wake.
        print("neend to sleep.")
        coroutine.yield()
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

    sendCoOut(cjson.encode(func))

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

    res, msg = coroutine.resume(co, arg.period)
    system.coReport(co, res, msg)
    if arg.loop == 0 then
        var.periodWakeCo[coId] = nil   -- free wait.
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
    assert(period >= 1, "period arg should greater than 1.")
    assert(loop >= 1, "loop should greater than 1.")
    local func = {
        func = "reqPeriodWake",
        arg = {
            id = var.id,
            coId = periodWakeGetId(),
            period = period,
            loop = loop,
        }
    }
    sendCoOut(cjson.encode(func))
    return coroutine.yield()
end

function M.msleep(ms)
    if ms < 1 then
        return
    end
    return M.periodWake(ms, 1)
end

return M