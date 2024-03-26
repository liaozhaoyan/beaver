require("eclass")

local userVar = require("module.userVar")
local system = require("common.system")
local CservLoop = require("app.servLoop")

local CuniServ = class("uniServ")

function CuniServ:_init_(thread)  -- thread contains beaver, conf, yaml
    self._thread = thread
    self._beaver = thread.beaver
    system.dumps(thread.yaml.user)
    local conf = thread.yaml.user
    self._conf = {
        uniSock = conf.path,
        mode = conf.mode or 'TCP'
    }
end

function CuniServ:proc()
    userVar.acceptSetup(CservLoop, self._beaver, self._conf)
    while true do
        userVar.msleep(3000)
    end
end

return CuniServ
