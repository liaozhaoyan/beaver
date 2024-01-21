---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 6:51 PM
---

-- refer to https://blog.csdn.net/zx_emily/article/details/83024065

local M = {}
local sockerUrl = require("socket.url")
local pystring = require("pystring")

local defaultHttpReadOvertime = 15

local function parseParam(param)
    local tParam = pystring.split(param, "&")
    local res = {}
    for _, s in ipairs(tParam) do
        local kv = pystring.split(s, "=")
        if #kv ~= 2 then
            print("bad param " .. s)
            return nil
        end
        local k = sockerUrl.unescape(kv[1])
        local v = sockerUrl.unescape(kv[2])
        res[k] = v
    end
    return res
end

function M.parseParams(tUrl)
    if tUrl.query then
        tUrl.queries = parseParam(tUrl.query)
    end
    if tUrl.params then
        tUrl.paramses = parseParam(tUrl.params)
    end
    return tUrl
end

function M.parseUrl(url, parseParam)
    local tUrl = sockerUrl.parse(url)  -- refer to https://lunarmodules.github.io/luasocket/url.html
    if parseParam then
        return M.parseParams(tUrl)
    else
        return tUrl
    end
end

local function waitDataRest(fread, rest, tReq)
    local len = 0
    local tStream = {tReq.body}
    local c = #tStream
    while len < rest do
        local s = fread(defaultHttpReadOvertime)
        if s then
            len = len + #s
            c = c + 1
            tStream[c] = s
        else
            return -1
        end
    end
    tReq.body = table.concat(tStream)
    return 0
end

local function waitChuckData(fread, s, size)
    while true do
        if #s >= size + 2 then
            return s
        end
        local add = fread(defaultHttpReadOvertime)
        if add then
            s = s .. add
        else
            return nil
        end
    end
end

local function waitChuckSize(fread, s)
    while true do
        if string.find(s, "\r\n") then
            return s
        end
        local add = fread(defaultHttpReadOvertime)
        if add then
            s = s .. add
        else
            return nil
        end
    end
end

local function readChunks(fread, tReq)
    local cells = {}
    local s = tReq.body
    local size
    local len = 1
    local bodies, body

    while true do
        if len == 0 then
            break
        end
        s = waitChuckSize(fread, s)
        if s then
            size, s = unpack(pystring.split(s, "\r\n", 1))
            len = tonumber(size, 16)
            if len then
                bodies = waitChuckData(fread, s, len)
                if bodies then
                    body = string.sub(bodies, 1, len)
                    s = string.sub(bodies, len + 2)
                    table.insert(cells, body)
                else
                    return -2
                end
            else
                return -3
            end
        else
            return -1
        end
    end
    tReq.body = table.concat(cells)
    return 0
end

local function waitHttpRest(fread, tReq)
    local length = tReq.headers["content-length"]
    if length then
        local lenData = #tReq.body
        local lenInfo = tonumber(length)

        local rest = lenInfo - lenData
        if rest > 10 * 1024 * 1024 then  -- limit max body len
            return -1
        end

        if waitDataRest(fread, rest, tReq) < 0 then
            return -2
        end
    else  -- chunk mode
        if tReq.body then
            if #tReq.body > 0 then
                if readChunks(fread, tReq) < 0 then
                    return -3
                end
            end
        else
            tReq.body = ""  --empty body.
        end
    end
    return 0
end

local function waitHttpHead(fread, tmo)
    local stream = ""
    while true do
        local s = fread(tmo)
        if s then
            stream = stream .. s
            tmo = defaultHttpReadOvertime
            if string.find(stream, "\r\n\r\n") then
                return stream
            end
        else
            return nil
        end
    end
end

local function serverParse(fread, stream, parseParam)
    local tStatus = pystring.split(stream, "\r\n", 1)
    if #tStatus < 2 then
        print("bad stream format.")
        return nil
    end

    local stat, heads = unpack(tStatus)
    local tStat = pystring.split(stat, " ", 2)
    if #tStat < 3 then
        print("bad stat: "..stat)
        return nil
    end

    local verb, url, version = unpack(tStat)
    local tReq
    tReq = M.parseUrl(url, parseParam)
    tReq.verb = string.lower(verb)
    tReq.version = version
    tReq.origUrl = url

    local tHead = pystring.split(heads, "\r\n\r\n", 1)
    if #tHead < 2 then
        print("bad head: " .. heads)
        return nil
    end
    local headerStr, body = unpack(tHead)
    local tHeader = pystring.split(headerStr, "\r\n")
    local headers = {}
    for _, s in ipairs(tHeader) do
        local tKv = pystring.split(s, ":", 1)
        if #tKv < 2 then
            print("bad head kv value: " .. s)
            return nil
        end
        local k, v = unpack(tKv)
        k = string.lower(k)
        headers[k] = pystring.lstrip(v)
    end

    tReq.headers = headers
    tReq.body = body
    if waitHttpRest(fread, tReq) < 0 then
        return nil
    end
    return tReq
end

function M.serverRead(fread, parseParam)
    local stream = waitHttpHead(fread, -1)
    if stream == nil then   -- read return stream or error code or nil
        return nil
    end
    return serverParse(fread, stream, parseParam)
end

local function clientParse(fread, stream)
    local tStatus = pystring.split(stream, "\r\n", 1)
    if #tStatus < 2 then
        print("bad stream format.")
        return nil
    end

    local stat, heads = unpack(tStatus)
    local tStat = pystring.split(stat, " ", 2)
    if #tStat < 3 then
        print("bad stat: " .. stat)
        return nil
    end

    local vers, code, descr = unpack(tStat)
    local tRes = {
        vers = vers,
        code = code,
        descr = descr
    }

    local tHead = pystring.split(heads, "\r\n\r\n", 1)
    if #tHead < 2 then
        print("bad head: " .. heads)
        return nil
    end
    local headerStr, body = unpack(tHead)
    local tHeader = pystring.split(headerStr, "\r\n")
    local headers = {}
    for _, s in ipairs(tHeader) do
        local tKv = pystring.split(s, ":", 1)
        if #tKv < 2 then
            print("bad head kv value: " .. s)
            return nil
        end
        local k, v = unpack(tKv)
        k = string.lower(k)
        headers[k] = pystring.lstrip(v)
    end
    tRes.headers = headers
    tRes.body = body
    if waitHttpRest(fread, tRes) < 0 then
        return nil
    end
    return tRes
end

function M.clientRead(fread)
    local stream = waitHttpHead(fread, 10 * defaultHttpReadOvertime)
    if stream == nil then   -- read return stream or error code or nil
        return nil
    end
    return clientParse(fread, stream)
end

return M
