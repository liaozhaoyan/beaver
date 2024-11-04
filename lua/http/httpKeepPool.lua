local require = require
require("eclass")
local system = require("common.system")
local workVar = require("module.workVar")
local parseUrl = require("common.parseUrl")

local ChttpReq = require("http.httpReq")
local ChttpPool = require("http.httpPool")
local format = string.format
local yield = coroutine.yield
local create = coroutine.create
local running = coroutine.running
local resume = coroutine.resume
local status = coroutine.status
local pairs = pairs
local ipairs = ipairs
local next = next
local coReport = system.coReport
local print = print
local error = error
local msleep = workVar.msleep
local type = type
local time = os.time
local parsePath = parseUrl.parsePath
local tonumber = tonumber
local class = class

local beaver = workVar.workerGetVar().beaver

local keepMaxSeconds = 10 -- keep 10 seconds
local ChttpKeepPool = class("httpKeepPool", ChttpPool)

function ChttpKeepPool:_init_(conf, maxConn, maxPool, guardPeriod)
    conf.port = tonumber(conf.port)
    self._conf = conf
    self._host = conf.host
    self._port = conf.port
    self._idle = {}  -- for idle connection. key is coroutine, value is timestamp.
    ChttpPool._init_(self, maxConn, maxPool, guardPeriod)
end

function ChttpKeepPool:confGet()
    return self._conf
end

function ChttpKeepPool:conn2idle()
    local co = running()
    -- call from coWork, set connection to idle stat.
    self._idle[co] = time()
    self._conn[co] = nil
    self._count = self._count - 1   -- reduce count
end

function ChttpKeepPool:idle2conn(reqs, co)
    -- call from coWork, set connection to working stat.
    self._idle[co] = nil
    self._conn[co] = reqs
    self._count = self._count + 1  -- add count
end

function ChttpKeepPool:idle2die()
    -- call from coWork, set connection to die stat.
    local co = running()
    self._idle[co] = nil
end

local function httpPoolwork(o, reqs)
    local res, msg
    beaver:co_yield()  -- release callchain from ChttpPool:req

    local conf = o:confGet()
    local tReq = {
        beaver = beaver
    }

    local req
    while true do
        if not req or req:status() ~= 1 then  -- reuse or create new req
            if req then
                req:close()
            end
            req = ChttpReq.new(tReq, conf.host, conf.port, conf.tmo, conf.proxy, conf.maxLen)
            if req:status() ~= 1 then
                print(format("create http req failed, domain:%s port:%s", conf.host, conf.port))
                break
            end
            req:reuse(true)  -- remember to close when req:status() == 1
        end
        res = req:_req(reqs.verb, reqs.url, reqs.headers, reqs.body)
        local coWake = reqs._toWake
        if status(coWake) == "suspended" then  -- only to wake suspended coroutine.
            res, msg = resume(coWake, res)  -- wake to ChttpPool:req
            coReport(coWake, res, msg)
        end

        -- try get next reqs
        reqs = o:poolGet()
        if not reqs then
            -- if no reqs, set connection to idle stat
            o:conn2idle()

            -- wake from resume, from ChttpKeepPool:_req, pick from next(self._idle)
            reqs = yield(0)  -- yield 0 means reuse connection.
            if reqs then
                beaver:co_yield() -- release callchain from ChttpPool:_req, self._idle co wake. 
                o:idle2conn(reqs, running())  -- set connection to working stat.
            else
                -- guard thread may close idle connection if overtime.
                o:idle2die() -- set connection to die stat.
                break
            end
        end
    end
    if req then
        req:close()
    end
end

function ChttpKeepPool:_req(reqs)
    local co, res, msg

    co = next(self._idle)
    if co then
        res, msg = resume(co, reqs)
        coReport(co, res, msg)
        return
    end

    co = create(httpPoolwork)
    res, msg = resume(co, self, reqs)
    coReport(co, res, msg)
    self._conn[co] = reqs  -- add to working connection.
    self._count = self._count + 1
end

function ChttpKeepPool:req(reqs)
    local _, domain, port, _ = parsePath(reqs.url)
    if (domain == self._host and tonumber(port) == self._port) then  -- domain and port match
        reqs._toWake = running()
        if self:connFull() then
            if not self:poolFull() then
                self:poolAdd(reqs)
            else
                return nil, "pool is full"
            end
        else
            self:_req(reqs)
        end
        local res, msg
        res, msg = yield() -- wait from httpPoolwork
        if type(res) == "table" then
            return res, msg
        else
            -- local connect may cloesed, then will resume a cdata closed event.
            return nil, format("local connection is closed.")
        end
    else
        return nil, format("domain:%s port:%s not match for this pool", domain, port)
    end
end

function ChttpKeepPool:get(url)
    local reqs = {
            url = url,
            verb = "GET",
        }
    return self:req(reqs)
end

function ChttpKeepPool:post(url, headers, body)
    local reqs = {
            url = url,
            verb = "POST",
            headers = headers,
            body = body,
        }
    return self:req(reqs)
end

function ChttpKeepPool:guardLoop()  -- call from guard thread
    ChttpPool.guardLoop(self)  -- check connection is alive

    local res, msg
    local now = time()
    local c = 0
    for co, ts in pairs(self._idle) do
        if now - ts > keepMaxSeconds then
            res, msg = resume(co, nil)  -- overtime, close idle connection. call httpPoolwork 
            coReport(co, res, msg)
        end
        c = c + 1
    end
end

return ChttpKeepPool
