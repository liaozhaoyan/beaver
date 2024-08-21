---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 5:31 PM
---

require("eclass")

local pystring = require("pystring")
local system = require("common.system")
local httpComm = require("http.httpComm")
local httpRead = require("http.httpRead")
local Ctrie = require("common.trie")

local liteAssert = system.liteAssert
local ipairs = ipairs
local pairs = pairs
local assert = assert
local lower = string.lower
local find = string.find
local format = string.format
local serverRead = httpRead.serverRead

local class = class
local systemPcall = system.pcall
local lastError = system.lastError
local ChttpInst = class("httpInst")

function ChttpInst:_init_()
    self._cbs = {
        get = Ctrie.new(),
        put = Ctrie.new(),
        post = Ctrie.new(),
        delete = Ctrie.new()
    }
end


function ChttpInst:_verbRegister(verb, path, func)
    local cb = self._cbs[verb]

    liteAssert(cb, format("bad verb mode: %s", verb))
    assert(cb:add(path, func))
end

function ChttpInst:get(path, func)
    self:_verbRegister("get", path, func)
end

function ChttpInst:put(path, func)
    self:_verbRegister("put", path, func)
end

function ChttpInst:post(path, func)
    self:_verbRegister("post", path, func)
end

function ChttpInst:delete(path, func)
    self:_verbRegister("delete", path, func)
end

local function echo404(path, verb)
    return {
        code = 404,
        headers = {
            ["Content-Type"] = "text/plain",
        },
        body = format("Oops! Beaver may have forgotten verb %s path %s on Mars!!!\n", verb, path),
        keep = false
    }
end

local function echo501(verb)
    return {
        code = 501,
        headers = {
            ["Content-Type"] = "text/plain",
        },
        body = format("Oops! Beaver may have gotten lost for %s!!!\n", verb),
        keep = false
    }
end

local function echo503(path, msg)
    local body = format("Oh! Beaver may have a bad stomach!!!\nhe eat %s, report: %s\n", path, msg)
    return {
        code = 503,
        headers = {
            ["Content-Type"] = "text/plain",
        },
        body = body,
        keep = false
    }
end

local function _proc(cbs, verb, tReq)
    local cb = cbs[verb]
    if cb then
        local path = tReq.path
        local ok, res
        local func, vars = cb:match(path)
        if func then
            tReq.Param = vars
            ok, res = systemPcall(func, tReq)
        else
            return echo404(path, verb)
        end

        if ok and res then  -- call success.
            res.session = tReq.session
            if not res.code then
                res.code = 200
            end
            return res
        else  -- res nil, bad state.
            return echo503(tReq.path, lastError())
        end
    end
    return echo501(verb)
end

local commPackServerFrame = httpComm.packServerFrame
function ChttpInst:packServerFrame(tReq)
    return commPackServerFrame(tReq)
end

function ChttpInst:proc(fread, session, clients, beaver, fd)
    local tReq = serverRead(fread)
    if tReq then
        tReq.session = session
        tReq.clients = clients
        tReq.beaver = beaver
        tReq.fd = fd
        local tRes = _proc(self._cbs, tReq.verb, tReq)
        local keep = true
        if tReq.headers and tReq.headers.connection then
            local con = tReq.headers.connection
            if lower(con) ~= 'keep-alive' then
                keep = false
            end
        end
        tRes.keep = keep
        return tRes
    end
    return nil
end

return ChttpInst
