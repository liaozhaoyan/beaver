---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/7 8:43 AM
---

local unistd = require("posix.unistd")
local CasyncPipeWrite = require("async.asyncPipeWrite")
local CasyncDns = require("async.asyncDns")
local system = require("common.system")

local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local lyaml = require("lyaml")
local cjson = require("cjson.safe")
local json = cjson.new()
json.encode_escape_forward_slash(false)

local M = {}

local var = {
    workers = {},   -- masters children
    setup = false,
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
            local res, msg = coroutine.resume(co, thread.beaver, w)
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
        coroutine.resume(var.coOut, json.encode(ret))
    end
    return 0
end

local function workerReg(arg)
    local w = arg.id
    print(string.format("thread %d is already online", w))
    var.workers[w][1] = true
end

local function reqDns(arg)
    local w = arg.id
    local coId = arg.coId
    local domain = arg.domain

    local ip = var.dns:request(domain)
    local func = {
        func = "echoDns",
        arg = {
            coId = coId,
            domain = domain,
            ip = ip
        }
    }
    local co = var.workers[w][4]  -- refer to pipeCtrlReg
    coroutine.resume(co, json.encode(func))
end

local funcTable = {
    pipeCtrlReg = function(arg) return pipeCtrlReg(arg)  end,
    workerReg = function(arg) return workerReg(arg) end,
    reqDns = function(arg) return reqDns(arg)  end
}

function M.call(arg)
    return funcTable[arg.func](arg.arg)
end

function M.masterSetVar(beaver, conf, yaml)
    var.thread = {
        beaver = beaver,
        conf = conf,
        yaml = yaml,
    }
    var.dns = CasyncDns.new(beaver)
end

function M.masterGetVar()
    return var.thread
end

return M