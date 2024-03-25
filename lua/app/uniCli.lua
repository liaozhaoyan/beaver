require("eclass")

local userVar = require("module.userVar")
local system = require("common.system")
local sockComm = require("common.sockComm")
local CcliLoop = require("app.cliLoop")

local CuniCli = class("uniCli")

function CuniCli:_init_(thread)  -- thread contains beaver, conf, yaml
    self._thread = thread
    self._beaver = thread.beaver
    system.dumps(thread.yaml.user)
    local conf = thread.yaml.user
    self._conf = {
        uniSock = conf.path,
    }
end

function CuniCli:proc()
    local tmo = 10
    local beaver = self._beaver

    local tPort = {path = self._conf.uniSock}

    while true do
        print("test for uniCli.")
        local fd = sockComm.connectSetup(tPort)
        CcliLoop.new(beaver,fd, tPort, tmo)
        userVar.msleep(1000)
    end
end

return CuniCli