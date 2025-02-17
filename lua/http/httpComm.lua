---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/3 9:13 PM
---

--- refer to https://blog.csdn.net/a19881029/article/details/14002273
local require = require
local pystring = require("pystring")
local sockerUrl = require("socket.url")

local tostring = tostring
local tonumber = tonumber
local print = print
local ipairs = ipairs
local pairs = pairs
local concat = table.concat
local split = pystring.split
local url_unescape = sockerUrl.unescape
local url_parse = sockerUrl.parse
local format = string.format
local os_date = os.date
local os_time = os.time
local type = type

local mt = {}

local function parseParam(param)
    local tParam = split(param, "&")
    local res = {}
    for _, s in ipairs(tParam) do
        local kv = split(s, "=")
        if #kv ~= 2 then
            print(format("bad param %s", s))
            return nil
        end
        local k = url_unescape(kv[1])
        local v = url_unescape(kv[2])
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

function mt.parsePath(path)
    local res = url_parse(path)
    return parseParams(res)
end

local codeStrTable = {
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
    [405] = "Not Acceptable",
    [418] = "I'm a beaver",
    [424] = "Failed Dependency",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [503] = "Service Unavailable",
}
local function packStat(code)   -- only for server.
    code = code or 200
    local t = {"HTTP/1.1", tostring(code), codeStrTable[code] or "Unkonwn"}
    return concat(t, " ")
end

local function originServerHeader()
    return {
        server = "beaver/0.1.0",
        date = os_date("%a, %d %b %Y %H:%M:%S %Z", os_time()),
    }
end

local function packServerHeaders(headers, len) -- just for http out.
    local heads = {}
    if not headers then
        headers = {
            ["Content-Type"] = "text/plain",
        }
    end

    if not headers["Content-Length"] then
        headers["Content-Length"] = tonumber(len)
    end
    local origin = originServerHeader()

    local c = 1
    for k, v in pairs(origin) do
        heads[c] = concat({k, v}, ": ")
        c = c + 1
    end

    for k, v in pairs(headers) do
        heads[c] = concat({k, v}, ": ")
        c = c + 1
    end

    return concat(heads, "\r\n")
end

function mt.packServerFrame(res)
    local body = res.body
    if body and type(body) ~= "string" then
        body = tostring(body)
    end
    local tHttp = {
        packStat(res.code),
        packServerHeaders(res.headers, body and #body or 0),
        "",
        body
    }
    return concat(tHttp, "\r\n")
end

local function packCliLine(method, uri)
    local t = {method, uri, "HTTP/1.1"}
    return concat(t, " ")
end

local originCliHeader = {
    ["User-Agent"] = "beaverCli/0.1.0",
    Connection = "Keep-Alive",
}
local function packCliHeaders(headers, len)
    len = len or 0
    local heads = {}

    if not headers then
        headers = {
            ["Content-Type"] = "text/plain",
        }
    end
    if not headers["Content-Length"] and len > 0 then
        headers["Content-Length"] = tonumber(len)
    end
    local origin = originCliHeader

    local c = 0
    for k, v in pairs(origin) do
        c = c + 1
        heads[c] = concat({k, v}, ": ")
    end

    for k, v in pairs(headers) do
        c = c + 1
        heads[c] = concat({k, v}, ": ")
    end

    return concat(heads, "\r\n")
end

function mt.packClientFrame(res)
    local tHttp = {
        packCliLine(res.method, res.uri),
        packCliHeaders(res.headers, #res.body),
        "",
        res.body
    }
    return concat(tHttp, "\r\n")
end

return mt
