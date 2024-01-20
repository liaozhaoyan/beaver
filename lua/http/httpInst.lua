---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 5:31 PM
---

require("eclass")

local pystring = require("pystring")
local system = require("common.system")
local ChttpComm = require("http.httpComm")
local httpRead = require("http.httpRead")

local ChttpInst = class("httpInst", ChttpComm)

function ChttpInst:_init_()
    self._cbs = {
        get = {
            url = {},
            urlRe = {}
        },
        put = {
            url = {},
            urlRe = {}
        },
        post = {
            url = {},
            urlRe = {}
        },
        delete = {
            url = {},
            urlRe = {}
        }
    }

    ChttpComm._init_(self)
end

local function containsReservedCharacters(s)
    local reservedPattern = "[%.%+%-%*%?%[%]%^%$%(%)%%]"
    return string.find(s, reservedPattern) == nil
end

function ChttpInst:_verbRegister(verb, path, func)
    local cb = self._cbs[verb]

    assert(cb, "bad verb mode: " .. verb)

    if containsReservedCharacters(path) then
        assert(not cb.url[path], "the " .. path .. " is already registered.")
        cb.url[path] = func
    else
        assert(not cb.urlRe[path], "the " .. path .. " is already registered.")
        cb.urlRe[path] = func
    end
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

local function reSearch(urlRe, path)
    for re, func in pairs(urlRe) do
        if string.find(path, re) then
            return func
        end
    end
    return nil
end

local function echo404(path)
    return {
        code = 404,
        headers = {
            ["Content-Type"] = "text/plain",
        },
        body = string.format("Oops! Beaver may have forgotten %s on Mars!!!\n", path),
        keep = true
    }
end

local function echo501()
    return {
        code = 501,
        headers = {
            ["Content-Type"] = "text/plain",
        },
        body = "Oops! Beaver may have gotten lost!!!\n",
        keep = false
    }
end

local function echo503(path, msg)
    local body = string.format("Oh! beaver may have a bad stomach!!!\nhe eat %s, report: %s\n", path, msg)
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
        local func = cb.url[path]

        if func then  -- direct mode
            ok, res = system.pcall(func, tReq)
        else  -- reSearch
            func = reSearch(cb.urlRe, path)
            if func then
                ok, res = system.pcall(func, tReq)
            else  -- not such page
                return echo404(path)
            end
        end

        if ok and res then  -- call success.
            res.session = tReq.session
            if not res.code then
                res.code = 200
            end
            return res
        else  -- res nil, bad state.
            return echo503(tReq.path, system.lastError())
        end
    end
    return echo501()
end

function ChttpInst:proc(fread, session, beaver, fd)
    local tReq = httpRead.serverRead(fread)
    if tReq then
        tReq.session = session
        tReq.beaver = beaver
        tReq.fd = fd
        return _proc(self._cbs, tReq.verb, tReq)
    end
    return nil
end

return ChttpInst
