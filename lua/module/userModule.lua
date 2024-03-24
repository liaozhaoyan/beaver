require("eclass")
local CcoBeaver = require("coBeaver")
local system = require("common.system")
local CasyncPipeRead = require("async.asyncPipeRead")
local CasyncPipeWrite = require("async.asyncPipeWrite")
local userVar = require("module.userVar")

local lyaml = require("lyaml")
local cjson = require("cjson.safe")

local CuserModule = class("userModule")

function CuserModule:_init_(conf)
    self._conf = conf
end

local function pipeOut(b, fOut)
    local w = CasyncPipeWrite.new(b, fOut, 10)

    while true do
        local stream, toWake = coroutine.yield()
        local res, err = w:write(stream, toWake)
        assert(res, err)
    end
end

local function setupFuncs(var)
    -- body
    local func = var.yaml
    print(func.user.entry)
    local mod = require("app." .. func.user.entry)
    local r = mod.new(var)
    local co = coroutine.create(mod.proc)
    local res, msg = coroutine.resume(co, r)
    system.coReport(co, res, msg)
end

local function pipeIn(b, conf)
    local r = CasyncPipeRead.new(b, conf.fIn, -1)

    local coOut = coroutine.create(pipeOut)
    local res, msg = coroutine.resume(coOut, b, conf.fOut)
    system.coReport(coOut, res, msg)
    userVar.setPipeOut(coOut)

    while true do
        local s = r:read()
        local arg = cjson.decode(s)
        userVar.call(arg)
    end
end

function CuserModule:proc()
    local b = CcoBeaver.new()

    userVar.setVar(b, self._conf, lyaml.load(self._conf.config))
    local var = userVar.getVar()
    userVar.setCb(setupFuncs, var)

    local co = coroutine.create(pipeIn)
    local res, msg = coroutine.resume(co, b, self._conf)
    system.coReport(co, res, msg)
    b:poll()
    return 0
end

return CuserModule
