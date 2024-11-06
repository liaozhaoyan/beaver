local require = require
local mt = {}
local ChttpReq = require("http.httpReq")
local workVar = require("module.workVar")
local parseUrl = require("common.parseUrl")
local tonumber = tonumber

local parsePath = parseUrl.parsePath
local beaver = workVar.workerGetVar().beaver

local function setupReq(url, tmo, proxy, maxLen)
    local _, domain, port, uri = parsePath(url)
    if not domain then
        return nil, "bad url: " .. url
    end
    local tReq = {
        beaver = beaver
    }

    local req = ChttpReq.new(tReq, domain, tonumber(port), tmo, proxy, maxLen)
    if req:status() ~= 1 then
        return nil, "http connect failed."
    end
    return req, uri
end

function mt.get(url, header, body, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:get(uri, header, body)
end

function mt.post(url, header, body, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:post(uri, header, body)
end

function mt.put(url, header, body, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:put(uri, header, body)
end

function mt.delete(url, header, body, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:delete(uri, header, body)
end

return mt
