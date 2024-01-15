---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/7 8:43 AM
---

local unistd = require("posix.unistd")
local CasyncPipeWrite = require("async.asyncPipeWrite")
local CasyncDns = require("async.asyncDns")
local CmasterTimer = require("module.masterTimer")
local system = require("common.system")

local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local lru = require("lru")
local lyaml = require("lyaml")
local cjson = require("cjson.safe")
local json = cjson.new()
json.encode_escape_forward_slash(false)

local M = {}

local var = {
    setup = false,
    workers = {},   -- masters children

    -- for multi delay, loop >= 1
    periodWakeCo = {},   -- multi delayed,
    periodWakeId = 1,    -- index

    dnsBuf = lru.new(32),
    dnsOvertime = 10,   -- dnsOvertime for 10s
}

function M.masterSetPipeOut(coOut)
    var.coOut = coOut
end

local function pipeOut(b, fOut)
    local w = CasyncPipeWrite.new(b, fOut, 10)

    while true do
        local stream = coroutine.yield()
        local res, err, errno = w:write(stream)
        assert(res, err)
    end
end

local function pipeCtrlReg(arg)
    local res, msg
    if not var.setup then
        var.masterIn  = arg["in"]
        var.masterOut = arg["out"]

        local thread = var.thread
        for i = 1, thread.yaml.worker.number do
            local r, w, errno = unistd.pipe()
            if not r then
                error(string.format("create pipe failed, %s, errno %d", w, errno))
            end

            local pid = c_api.create_beaver(r, var.masterIn, "worker", thread.conf.config)

            local co = coroutine.create(pipeOut)
            res, msg = coroutine.resume(co, thread.beaver, w)
            assert(res, msg)
            var.workers[w] = {false, pid, r, co}   -- use w pipe to record single thread.

            local func = {
                func = "regThreadId",
                arg = {
                    id = w,
                }
            }
            res, msg = coroutine.resume(co, json.encode(func))
            assert(res, msg)
        end

        var.setup = true
        local ret = {ret = 0}
        res, msg = coroutine.resume(var.coOut, json.encode(ret))
        assert(res, msg)
    end
    return 0
end

local function workerReg(arg)
    local w = arg.id
    print(string.format("thread %d is already online", w))
    var.workers[w][1] = true
end

local function checkDns(domain)
    local buf = var.dnsBuf[domain]
    local now = os.time()

    if buf then
        local t = buf[2]

        if now - t > var.dnsOvertime then
            return nil, now
        else
            return buf[1], t
        end
    else
        return nil, now
    end
end

local function reqDns(arg)
    local fid = arg.id
    local coId = arg.coId
    local domain = arg.domain
    local ip, now

    ip, now = checkDns(domain)
    if not ip then
        ip = var.dns:request(domain)
        var.dnsBuf[domain] = {ip, now}
    end

    local func = {
        func = "echoDns",
        arg = {
            coId = coId,
            domain = domain,
            ip = ip
        }
    }
    local co = var.workers[fid][4]  -- refer to pipeCtrlReg
    local res, msg = coroutine.resume(co, json.encode(func))
    assert(res, msg)
end

local function reqPeriodWake(arg)
    local node = {
        fid = arg.id,
        coId = arg.coId,
        period = arg.period,
        loop = arg.loop
    }
    var.timer:add(node)
end

local funcTable = {
    pipeCtrlReg = function(arg) return pipeCtrlReg(arg)  end,
    workerReg = function(arg) return workerReg(arg) end,
    reqDns = function(arg) return reqDns(arg)  end,
    reqPeriodWake = function(arg) return reqPeriodWake(arg)  end,
}

function M.call(arg)
    return funcTable[arg.func](arg.arg)
end

local function periodWakeGetId()
    local ret = var.periodWakeId
    var.periodWakeCo[ret] = coroutine.running()
    var.periodWakeId = var.periodWakeId + 1
    return ret
end

local function timerWake(node) -- call in masterTimer.
    local res, msg
    local co
    local fid = node.id
    if fid > 0 then  -- wake worker
        local func = {
            func = "echoWake",
            arg = {
                coId = node.coId,
                loop = node.loop,
                period = node.period,
            }
        }
        co = var.workers[fid][4]  -- refer to pipeCtrlReg
        res, msg = coroutine.resume(co, json.encode(func))
        assert(res, msg)
    else
        co = var.periodWakeCo[node.coId]
        res, msg = coroutine.resume(co, node)
        assert(res, msg)
        if node.loop == 0 then
            var.periodWakeCo[node.coId] = nil
        end
    end
end

function M.periodWake(period, loop)
    assert(period >= 10, "period arg should greater than 10.")
    assert(loop >= 1, "")
    local node = {
        id = 0,
        coId = periodWakeGetId(),
        period = period,
        loop = loop,
    }

    var.timer:add(node)
    coroutine.yield()
end

function M.msleep(ms)
    return M.periodWake(ms, 1)
end

function M.masterSetVar(beaver, conf, yaml)
    var.thread = {
        beaver = beaver,
        conf = conf,
        yaml = yaml,
    }

    var.dns = CasyncDns.new(beaver)
    var.timer = CmasterTimer.new(beaver, timerWake)

    var.timer:start()
end

function M.masterGetVar()
    return var.thread
end

return M