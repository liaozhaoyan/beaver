local require = require
local mt = {}
local ChttpReq = require("http.httpReq")
local workVar = require("module.workVar")
local parseUrl = require("common.parseUrl")
local tonumber = tonumber

local parseHostUri = parseUrl.parseHostUri
local beaver = workVar.workerGetVar().beaver

local function setupReq(url, tReq, tmo, proxy, maxLen)
    local host, uri = parseHostUri(url)
    if not host then
        return nil, "bad url: " .. url
    end
    tReq = tReq or {
        beaver = beaver
    }

    local req = ChttpReq.new(tReq, host, nil, tmo, proxy, maxLen)
    if req:status() ~= 1 then
        return nil, "http connect failed."
    end
    return req, uri
end

function mt.get(url, header, body, tReq, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tReq, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:get(uri, header, body)
end

function mt.post(url, header, body, tReq, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tReq, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:post(uri, header, body)
end

function mt.put(url, header, body, tReq, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tReq, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:put(uri, header, body)
end

function mt.delete(url, header, body, tReq, tmo, proxy, maxLen)
    local req, msg = setupReq(url, tReq, tmo, proxy, maxLen)
    if not req then
        return req, msg
    end
    local uri = msg -- uri return by msg
    return req:delete(uri, header, body)
end

return mt
