require("eclass")
local CcoBeaver = require("coBeaver")
local system = require("common.system")
local CasyncPipeRead = require("async.asyncPipeRead")
local CasyncPipeWrite = require("async.asyncPipeWrite")
local userVar = require("module.userVar")
local heartbeate = require("module.heartBeat")

local lyaml = require("lyaml")
local cjson = require("cjson.safe")

local class = class
local CuserModule = class("userModule")

local require = require
local print = print
local format = string.format
local liteAssert = system.liteAssert
local coReport = system.coReport
local create = coroutine.create
local yield = coroutine.yield
local resume = coroutine.resume
local jdecode = cjson.decode

function CuserModule:_init_(conf)
    self._conf = conf
end

local function pipeOut(b, fOut)
    local w = CasyncPipeWrite.new(b, fOut, 10)

    while true do
        local stream, toWake = yield()
        local res, err = w:write(stream, toWake)
        liteAssert(res, err)
    end
end

local function setupFuncs(var)
    -- body
    local func = var.yaml
    print(func.user.entry)
    local mod = require(format("app.%s", func.user.entry))
    local r = mod.new(var)
    local co = create(mod.proc)
    local res, msg = resume(co, r)
    coReport(co, res, msg)
    heartbeate.start(userVar.msleep, "user")
end

local function pipeIn(b, conf)
    local r = CasyncPipeRead.new(b, conf.fIn, -1)

    local coOut = create(pipeOut)
    local res, msg = resume(coOut, b, conf.fOut)
    coReport(coOut, res, msg)
    userVar.setPipeOut(coOut)

    while true do
        local s = r:read()
        local arg = jdecode(s)
        userVar.call(arg)
    end
end

function CuserModule:proc()
    local b = CcoBeaver.new()
    b.var = userVar

    userVar.setVar(b, self._conf, lyaml.load(self._conf.config))
    local var = userVar.getVar()
    userVar.setCb(setupFuncs, var)

    local co = create(pipeIn)
    local res, msg = resume(co, b, self._conf)
    coReport(co, res, msg)
    b:poll()
    return 0
end

return CuserModule
