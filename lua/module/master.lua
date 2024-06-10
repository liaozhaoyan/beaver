---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/4 10:58 PM
---

require("eclass")
local unistd = require("posix.unistd")
local CcoBeaver = require("coBeaver")
local system = require("common.system")
local CasyncPipeRead = require("async.asyncPipeRead")
local CasyncPipeWrite = require("async.asyncPipeWrite")
local masterVar = require("module.masterVar")

local lyaml = require("lyaml")
local cjson = require("cjson.safe")

local class = class
local Cmaster = class("master")

local time = os.time
local liteAssert = system.liteAssert
local coReport = system.coReport
local create = coroutine.create
local yield = coroutine.yield
local resume = coroutine.resume
local format = string.format
local jdecode = cjson.decode

function Cmaster:_init_(conf)
    self._conf = conf
end

local function pipeOut(beaver, fOut)
    local w = CasyncPipeWrite.new(beaver, fOut, 10)

    while true do
        local stream = yield()
        local res, err, errno = w:write(stream)
        liteAssert(res, err)
    end
end

local function pipeIn(b, conf)  --> to receive call function
    local r = CasyncPipeRead.new(b, conf.fIn, -1)

    local coOut = create(pipeOut)
    local res, msg = resume(coOut, b, conf.fOut)
    coReport(coOut, res, msg)
    masterVar.masterSetPipeOut(coOut)

    while true do
        local s = r:read()
        local arg = jdecode(s)
        liteAssert(arg, format("decode arg failed. %s, len: %d", s, #s))
        masterVar.call(arg)
    end
end

function Cmaster:proc()
    local beaver = CcoBeaver.new()

    masterVar.masterSetVar(beaver, self._conf, lyaml.load(self._conf.config))

    local co = create(pipeIn)
    local res, msg = resume(co, beaver, self._conf)
    coReport(co, res, msg)

    beaver:poll()
    return 0
end

return Cmaster

