require("eclass")

local userVar = require("module.userVar")
local system = require("common.system")
local sockComm = require("common.sockComm")
local CcliLoop = require("app.cliLoop")
local CcliBase = require("client.cliBase")

local format = string.format

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
    local beaver = self._beaver
    userVar.msleep(1000)  -- to wait for  db sock is binding.
    local tPort = {path = self._conf.uniSock}

    while true do
        local cli = CcliBase.new(beaver,tPort)
        local list = {
            "hello world.",
            "hello lua.",
            "hello lua2.",
        }

        for _,v in pairs(list) do
            local res = cli:echo(v)
            assert(res == v, format("res:%s, v:%s", res, v))
        end
        local s = format("hello %d.", os.time())
        local res = cli:echo(s)
        assert(res == s, format("res:%s, v:%s", res, s))
        userVar.msleep(1000)
    end
end

return CuniCli