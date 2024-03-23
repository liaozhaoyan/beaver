require("eclass")

local userVar = require("module.userVar")
local system = require("common.system")
local format = string.format

local CuserTest = class("userTest")

function CuserTest:_init_(thread)  -- thread contains beaver, conf, yaml
    self._thread = thread 
    system.dumps(thread.yaml.user)
end

function CuserTest:proc()
    local user = self._thread.yaml.user
    local i = 0
    while true do
        print("hello world.")
        if user.args then
            i = i + 1
            print(format("args: %s, counter: %d", user.args, i))
        end
        userVar.msleep(2000)
    end
end
return CuserTest