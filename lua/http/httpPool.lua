local require = require
require("eclass")
local system = require("common.system")
local workVar = require("module.workVar")
local parseUrl = require("common.parseUrl")

local ChttpReq = require("http.httpReq")
local yield = coroutine.yield
local create = coroutine.create
local running = coroutine.running
local resume = coroutine.resume
local status = coroutine.status
local tonumber = tonumber
local debugTraceback = debug.traceback
local pairs = pairs
local coReport = system.coReport
local print = print
local msleep = workVar.msleep
local parsePath = parseUrl.parsePath

local class = class

local beaver = workVar.workerGetVar().beaver

local ChttpPool = class("httpPool")

local function gurad(o, guardPeriod)  -- pick dead connection from conn
    beaver:co_yield()
    while true do
        msleep(guardPeriod * 1000)
        o:guardLoop()
    end
end

function ChttpPool:_init_(maxConn, maxPool, guardPeriod)
    self._maxConn = maxConn or 4
    self._maxPool = maxPool or 1000
    self._conn = {}
    self._pool = {}
    self._count = 0
    self._poolHead = 1
    self._poolTail = 1

    local res, msg
    local co = create(gurad)
    res, msg = resume(co, self, guardPeriod or 2)  -- gurad per 2 seconds default.
    coReport(co, res, msg)
end

function ChttpPool:poolCount()
    return self._poolTail - self._poolHead
end

function ChttpPool:poolEmpty()
    return self._poolTail == self._poolHead
end

function ChttpPool:poolFull()
    return self._poolTail == self._poolHead + self._maxPool
end

function ChttpPool:poolAdd(reqs)
    self._pool[self._poolTail] = reqs
    self._poolTail = self._poolTail + 1
end

function ChttpPool:poolGet()
    if self:poolEmpty() then
        return nil
    end
    local reqs = self._pool[self._poolHead]
    self._pool[self._poolHead] = nil
    self._poolHead = self._poolHead + 1
    return reqs
end

function ChttpPool:connFull()
    return self._count == self._maxConn
end

local function httpPoolwork(o, reqs)
    beaver:co_yield()  -- release callchain from ChttpPool:req
    local req = ChttpReq.new(reqs.tReq, reqs.host, reqs.port, reqs.tmo, reqs.proxy, reqs.maxLen)
    local res = req:_req(reqs.verb, reqs.uri, reqs.headers, reqs.body)
    local coWake = o:freeConn(running())
    if status(coWake) == "suspended" then  -- only to wake suspended coroutine.
        resume(coWake, res)  -- wake to ChttpPool:req
    end
    o:pickPool2Conn()
end

function ChttpPool:freeConn(co)  -- call from httpPoolwork
    local toWake = self._conn[co]
    self._conn[co] = nil
    self._count = self._count - 1
    return toWake
end

function ChttpPool:_req(reqs)
    local co = create(httpPoolwork)
    local res, msg = resume(co, self, reqs)
    coReport(co, res, msg)

    self._conn[co] = reqs._toWake
    self._count = self._count + 1
end

function ChttpPool:pickPool2Conn()
    -- call from httpPoolwork, pick reqs from pool to conn
    if not self:poolEmpty() then
        local reqs = self:poolGet()
        self:_req(reqs)
    end
end

function ChttpPool:req(reqs)
    if reqs.tReq then
        reqs.tReq.fd = nil  -- strip host fd
    else
        reqs.tReq = {
            beaver = beaver
        }
    end
    reqs._toWake = running()
    if self:connFull() then  -- connect is full, add to pool
        if not self:poolFull() then  -- pool is not full, add to pool
            self:poolAdd(reqs)
        else   -- pool is full, return nil.
            return nil, "pool is full"
        end
    else    -- connect is not full, create new connection
        self:_req(reqs)
    end

    local res, msg
    res, msg = yield() -- wait from httpPoolwork
    return res, msg
end

function ChttpPool:get(url, tmo, maxLen)
    local _, domain, port, _ = parsePath(url)
    local reqs = {
        host = domain,
        port = tonumber(port),
        verb = "GET",
        uri = url,
        tmo = tmo or 10,
        proxy = nil,
        maxLen = maxLen or 2 * 1024 * 1024
    }
    return self:req(reqs)
end

function ChttpPool:guardLoop()
    for co, coWake in pairs(self._conn) do
        if status(co) == "dead" then  -- connection is dead, remove it.
            self._conn[co] = nil
            self._count = self._count - 1
            print("connection is dead, remove it. " .. debugTraceback(co))
            if status(coWake) == "suspended" then -- wake to ChttpPool:req
                resume(coWake, nil, "connection is dead")
            end
            self:pickPool2Conn()  -- pick reqs from pool to conn
        end
    end
end

return ChttpPool
