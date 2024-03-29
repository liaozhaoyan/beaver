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

function ChttpComm:jencode(t)
    return cjson.encode(t)
end

function ChttpComm:jdecode(s)
    return cjson.decode(s)
end

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
    [418] = "I'm a beaver",
    [500] = "Internal Server Error",
    [501] = "Not Implemented",
    [503] = "Service Unavailable",
}
local function packStat(code)   -- only for server.
    local t = {"HTTP/1.1", tostring(code), codeStrTable[code]}
    return table.concat(t, " ")
end

local function originServerHeader()
    return {
        server = "beaver/0.1.0",
        date = os.date("%a, %d %b %Y %H:%M:%S %Z", os.time()),
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
        heads[c] = table.concat({k, v}, ": ")
        c = c + 1
    end

    for k, v in pairs(headers) do
        heads[c] = table.concat({k, v}, ": ")
        c = c + 1
    end

    return table.concat(heads, "\r\n")
end

function ChttpComm:packServerFrame(res)
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
    return table.concat(tHttp, "\r\n")
end

local function packCliLine(method, url)
    local t = {method, url, "HTTP/1.1"}
    return table.concat(t, " ")
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
        heads[c] = table.concat({k, v}, ": ")
    end

    for k, v in pairs(headers) do
        c = c + 1
        heads[c] = table.concat({k, v}, ": ")
    end

    return table.concat(heads, "\r\n")
end

function ChttpComm:packClientFrame(res)
    local tHttp = {
        packCliLine(res.method, res.url),
        packCliHeaders(res.headers, #res.body),
        "",
        res.body
    }
    return table.concat(tHttp, "\r\n")
end

return ChttpComm
