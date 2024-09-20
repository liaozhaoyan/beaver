-- 仅支持短连接场景，长连接禁止使用

local require = require
require("eclass")

local system = require("common.system")
local ChttpReq = require("http.httpReq")
local workVar = require("module.workVar")
local pystring = require("pystring")

local type = type
local status = coroutine.status
local create = coroutine.create
local resume = coroutine.resume
local running = coroutine.running
local yield = coroutine.yield
local coReport = system.coReport
local class = class
local format = string.format
local collectgarbage = collectgarbage
local wait = workVar.wait

collectgarbage("setpause", 150)
collectgarbage("setstepmul", 300)

local CtmoGet = class("tmoGet")

local proxy = {
    ip = "172.16.0.119",
    port = 3128
}

local counter = 1

local function index(tReq)
    counter = counter + 1
    return {body = format("beaver %d say hello.", counter)}
end

local function direct(tReq)
    local req = ChttpReq.new(tReq, "https://cn.bing.com/", nil, nil, proxy)
    local tRes = req:get("https://cn.bing.com/")
    if tRes then
        return {body = tRes.body}
    else
        return {body = "unknown"}
    end
end

local function _get(co, tReq)
    local req = ChttpReq.new(tReq, "https://cn.bing.com/", nil, nil, proxy)
    local tRes = req:get("https://cn.bing.com/")
    if status(co) == "suspended" then
        local ok, msg = resume(co, tRes.body)
        coReport(co, ok, msg)
    else
        print("co is dead, may time out exit.")
    end
end

local function tmoGet(tReq)
    local coWake = running()
    local co = create(_get)
    local ok, msg = resume(co, coWake, tReq)
    coReport(co, ok, msg)
    wait(coWake, 200)  -- 200ms tmo
    local res = yield()
    if type(res) == "number" then
        return {body = "timeout: " .. res}
    else
        return {body = res}
    end
end

function CtmoGet:_init_(inst, conf)
    inst:get("/", index)
    inst:get("/direct", direct)
    inst:get("/tmo", tmoGet)
end

return CtmoGet