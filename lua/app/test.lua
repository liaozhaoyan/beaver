---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 4:44 PM
---

require("eclass")

local system = require("common.system")
local pystring = require("pystring")
local cjson = require("cjson.safe")
local ChttpReq = require("http.httpReq")
local httpRead = require("http.httpRead")
local Credis = require("client.redis")
local CcliBase = require("client.cliBase")
local redisTest = require("app.redisTest")

local class = class
local Ctest = class("test")
local collectgarbage = collectgarbage
local string = string

collectgarbage("setpause", 150)
collectgarbage("setstepmul", 300)

local counter = 0

local function index(tReq)
    counter = counter + 1
    return {body = string.format("beaver %d say hello.", counter)}
end

local proxy = {
    ip = "172.16.0.119",
    port = 3128
}

local function instance(tReq)
    local req = ChttpReq.new(tReq, "100.100.100.200", 80)
    local tRes = req:get("/latest/meta-data/instance-id")
    if tRes then
        return {body = tRes.body}
    else
        return {body = "unknown"}
    end
end

local function bing(tReq)
    local req = ChttpReq.new(tReq, "https://cn.bing.com/", nil, nil, proxy)
    local tRes = req:get("HTTPS://cn.bing.com/")
    if tRes then
        return {body = tRes.body}
    else
        return {body = "unknown"}
    end
end

local function baidu(tReq)
    local req = ChttpReq.new(tReq, "http://www.baidu.com/", nil, nil, proxy)
    local tRes = req:get("HTTP://www.baidu.com/")
    if tRes then
        return {body = tRes.body}
    else
        return {body = "unknown"}
    end
end

local function unkown(tReq)
    local req = ChttpReq.new(tReq, "www.unknown.com")
    local tRes = req:get("HTTP://www.unknown.com/")
    if tRes then
        print(tRes.body)
        return {body = tRes.body}
    end
end

local function svg(tReq)
    httpRead.parseParams(tReq)
    system.dumps(tReq)
    local body = [[<svg width="100" height="100">
    <circle cx="50" cy="50" r="40" stroke="black" stroke-width="3" fill="red" />
  </svg>]]
    return {
        body = body,
        headers = {
            ["Content-Type"] = "image/svg+xml",
        }
    }
end

local function var(tReq)
    local param = tReq.Param["var"]
    return {
        body = string.format("url set: %s", tostring(param))
    }
end

local function rcmd(tReq)
    local r = Credis.new(tReq, "127.0.0.1", 6379, nil, "alibaba")
    local s = tReq.body

    local cmd, argStr = unpack(pystring.split(s, " ", 1))
    local args = {}
    if argStr then
        args = pystring.split(argStr, ":")
    end
    local res = r[cmd](r, unpack(args))

    if res then
        if type(res) == "table" then
            res = cjson.encode(res)
        end
        return {body = res}
    end
end

local function gcInfo(tReq)
    return {body = string.format("mem: %d", collectgarbage("count"))}
end

local function rcmds(tReq)
    local r = Credis.new(tReq, "127.0.0.1", 6379, nil, "alibaba")
    local pipe = r:pipeline()

    local s = tReq.body
    local cmds = pystring.split(s, "\n")
    for _, cmdLine in ipairs(cmds) do
        local cmd, argStr = unpack(pystring.split(cmdLine, " ", 1))
        local args = {}
        if argStr then
            args = pystring.split(argStr, ":")
        end
        pipe[cmd](pipe, unpack(args))
    end
    local res = pipe:send()
    if res then
        return {body = cjson.encode(res)}
    end
end

local function uds(tReq)
    local tPort = {path = "db.sock"}
    local cli = CcliBase.new(tReq.beaver, tPort)
    local res = cli:echo("hello, uds.")
    cli:close()
    if res then
        return {body = cjson.encode(res)}
    end
end

local function probe(code)
    print("code: ", code)
end

function Ctest:_init_(inst, conf)
    -- redisTest.start()
    inst:setProbe(probe)
    inst:get("/", index)
    inst:get("/instance", instance)
    inst:get("/bing", bing)
    inst:get("/baidu", baidu)
    inst:get("/unkown", unkown)
    inst:get("/gc", gcInfo)
    inst:get("/svg", svg)
    inst:get("/var/:var", var)
    inst:post("/rcmd", rcmd)
    inst:post("/rcmds", rcmds)
    inst:get("/uds", uds)
end

return Ctest
