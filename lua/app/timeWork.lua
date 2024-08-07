local require = require

local socket = require("socket")
local workVar = require("module.workVar")

local print = print
local gettime = socket.gettime
local create = coroutine.create
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local msleep = workVar.msleep

local mt = {}

local timer

local function timerTest2()
    local i = 0
    while i < 10000 do
        local t1 =  gettime()
        msleep(2000)
        local t2 = gettime()
        assert(t2 - t1 >= 1.9 and t2 - t1 <= 2.1)
        i = i + 1
    end
    print("stop test2")
end

local function timerTest3()
    local i = 0
    while i < 10000 do
        local t1 = gettime()
        msleep(3000)
        local t2 = gettime()
        assert(t2 - t1 >= 2.9 and t2 - t1 <= 3.1)
        i = i + 1
    end
    print("stop test3")
end

function mt.call(beaver, args)
    print("run test.")
    local co = create(timerTest2)
    resume(co)
    co = create(timerTest3)
    resume(co)
end

return mt
