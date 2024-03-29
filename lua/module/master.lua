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

local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api
local format = string.format

local lyaml = require("lyaml")
local cjson = require("cjson.safe")


local Cmaster = class("master")

function Cmaster:_init_(conf)
    self._conf = conf
end

local function pipeOut(beaver, fOut)
    local w = CasyncPipeWrite.new(beaver, fOut, 10)

    while true do
        local stream = coroutine.yield()
        local res, err, errno = w:write(stream)
        assert(res, err)
    end
end

local function pipeIn(b, conf)  --> to receive call function
    local r = CasyncPipeRead.new(b, conf.fIn, -1)

    local coOut = coroutine.create(pipeOut)
    local res, msg = coroutine.resume(coOut, b, conf.fOut)
    system.coReport(coOut, res, msg)
    masterVar.masterSetPipeOut(coOut)

    while true do
        local s = r:read()
        local arg = cjson.decode(s)
        masterVar.call(arg)
    end
end

local function check(last, hope)
    local now = os.time()
    assert(now - last == hope or now - last == hope + 1, format("check var failed. hope: %d, now: %d", hope, now - last))
    return now
end

local function testTimer()
    local last = os.time()
    local loop = 1
    while true do
        masterVar.msleep(3000)
        last = check(last, 3)
        masterVar.msleep(5000)
        last = check(last, 5)
        loop = loop + 1
    end
end

function Cmaster:proc()
    local beaver = CcoBeaver.new()

    masterVar.masterSetVar(beaver, self._conf, lyaml.load(self._conf.config))

    local co = coroutine.create(pipeIn)
    local res, msg = coroutine.resume(co, beaver, self._conf)
    system.coReport(co, res, msg)

    co = coroutine.create(testTimer)
    res, msg = coroutine.resume(co)
    system.coReport(co, res, msg)

    beaver:poll()
    return 0
end

return Cmaster

