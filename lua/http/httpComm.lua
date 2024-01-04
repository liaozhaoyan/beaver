---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/3 9:13 PM
---

--- refer to https://blog.csdn.net/a19881029/article/details/14002273

require("eclass")
local pystring = require("pystring")
local sockerUrl = require("socket.url")

local ChttpComm = class("httpComm")

local cjson = require("cjson.safe")
local json = cjson.new()

json.encode_escape_forward_slash(false)

local function codeTable()
    return {
        [100] = "Continue",
        [200] = "Ok",
        [201] = "Created",
        [202] = "Accepted",
        [204] = "No Content",
        [206] = "Partial Content",
        [301] = "Moved Permanently",
        [302] = "Found",
        [304] = "Not Modified",
        [400] = "Bad Request",
        [401] = "Unauthorized",
        [403] = "Forbidden",
        [404] = "Not Found",
        [418] = "I'm a beaver",
        [500] = "Internal Server Error",
        [501] = "Not Implemented"
    }
end

function ChttpComm:jencode(t)
    return json.encode(t)
end

function ChttpComm:jdecode(s)
    return json.decode(s)
end

local function parseParam(param)
    local tParam = pystring:split(param, "&")
    local res = {}
    for _, s in ipairs(tParam) do
        local kv = pystring:split(s, "=")
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

local function parseParams(tUrl)
    if tUrl.query then
        tUrl.queries = parseParam(tUrl.query)
    end
    if tUrl.params then
        tUrl.paramses = parseParam(tUrl.params)
    end
    return tUrl
end

function ChttpComm:parsePath(path)
    local res = sockerUrl.parse(path)
    return parseParams(res)
end

local function originServerHeader()
    return {
        server = "beaver/0.0.4",
        date = os.date("%a, %d %b %Y %H:%M:%S %Z", os.time()),
    }
end

function ChttpComm:packServerHeaders(headTable, len) -- just for http out.
    local lines = {}
    if not headTable["Content-Length"] then
        headTable["Content-Length"] = len
    end
    local origin = originServerHeader()

    local c = 1
    for k, v in pairs(origin) do
        lines[c] = table.concat({k, v}, ": ")
        c = c + 1
    end

    for k, v in pairs(headTable) do
        lines[c] = table.concat({k, v}, ": ")
        c = c + 1
    end

    lines[c] = ""
    return pystring:join("\r\n", lines)
end

local codeStrTable = codeTable()
function ChttpComm:packStat(code)   -- only for server.
    local t = {"HTTP/1.1", code, codeStrTable[code]}
    return pystring:join(" ", t)
end

local function originCliHeader()
    return {
        ["User-Agent"] = "beaverCli/0.0.4",
        Connection = "Keep-Alive",
    }
end

function ChttpComm:packCliHeaders(headTable, len)
    len = len or 0
    local lines = {}
    if not headTable["Content-Length"] and len > 0 then
        headTable["Content-Length"] = len
    end
    local origin = originCliHeader()

    local c = 0
    for k, v in pairs(origin) do
        c = c + 1
        lines[c] = table.concat({k, v}, ": ")
    end

    for k, v in pairs(headTable) do
        c = c + 1
        lines[c] = table.concat({k, v}, ": ")
    end

    c = c + 1
    lines[c] = ""
    return pystring:join("\r\n", lines)
end

function ChttpComm:packCliHead(method, url)
    local t = {method, url, "HTTP/1.1"}
    return pystring:join(" ", t)
end

return ChttpComm
