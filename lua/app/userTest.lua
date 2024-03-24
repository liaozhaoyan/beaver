require("eclass")

local userVar = require("module.userVar")
local system = require("common.system")
local socket = require("socket")

local msleep = userVar.msleep
local format = string.format

local CuserTest = class("userTest")

function CuserTest:_init_(thread)  -- thread contains beaver, conf, yaml
    self._thread = thread 
    system.dumps(thread.yaml.user)
end

local function loop()
    -- body
    local last = socket.gettime() * 1000
    local ms, now
    while true do
        ms = math.random(0, 5000)
        msleep(ms)
        now = socket.gettime() * 1000
        if now - last > ms + 10 then
            print(format("time: %d, hope: %d", now - last, ms))
        end
        last = now
    end
end

local function createCo(num)
    math.randomseed(os.time())
    for i = 1, num do
        local co = coroutine.create(loop)
        coroutine.resume(co)
    end
end

function CuserTest:proc()
    local user = self._thread.yaml.user
    local i = 0
    createCo(user.num)
    while true do
        print("hello world.")
        if user.args then
            i = i + 1
            print(format("args: %s, counter: %d", user.args, i))
        end
        msleep(2000)
    end
end
return CuserTest