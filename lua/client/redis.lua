local require = require
require("eclass")

local psocket = require("posix.sys.socket")
local pystring = require("pystring")
local system = require("common.system")
local workVar = require("module.workVar")
local CasyncClient = require("async.asyncClient")

-- refer to https://maling.io/docs/redis/resp-protocol/

local common_cmds = {
    "del",      "dump",         "exist",    "expire",
    "keys",     "move",         "persist",  "rename",
    "renamenx", "ttl",          "pexpire",  "expireat",
    "pttl",     "dbsize",       "radnomkey", "sort",
    "scan",                                             -- Key
    "get",      "set",          "mget",     "mset",
    "del",      "incr",         "decr",     "getrange",
    "setnx",    "setex",        "psetex",   "msetnx",
    "getset",   "incrby",       "incrbyfloat",  "decrby",
    "append",   "substr",       "strlen",   "setrange",
    "setbit",   "getbit",       "bittop",    "bitcount",-- Strings 
    "llen",     "lindex",       "lpop",     "lpush",
    "lrange",   "linsert",      "rpush",    "ltrim",
    "lset",     "lrem",         "rpop",     "rpoppush",
    "blpop",    "brpop",        "rpushx",   "lpushx",
    "brpoplpush",                                       -- Lists
    "hexists",  "hget",         "hset",     "hmget",
    "hdel",     "hgetall",      "hsetnx",   "hincrby",
    "hincrbyfloat","hdel",      "hexists",  "hlen",
    "hkeys",    "hvals",        "hscan",                -- Hashes
    "smembers", "sismember",    "sadd",     "srem",
    "sdiff",    "sinter",       "sunion",   "spop",
    "smove",    "sinterstore",  "sunionstore","sdiffstore",
    "srandomember","sscan",                            -- Sets
    "zrange",   "zrangebyscore", "zrank",   "zadd",
    "zrem",     "zincrby",      "zrevrange","zrevrangebyscore",
    "zunionstore","zinterstore", "zcount",  "zcard",
    "zscore",   "zremrangebyscore","zremrangebyrank",
    "zscan",                                           -- Sorted Sets
    "ping",     "echo",     "auth",     "select",      -- connection
    "multi",    "exec",     "discard",  "watch",
    "unwatch",                                         -- transactions
    "eval",     "evalsha",  "script",                  -- redis scripting
    "bgrewriteaof", "config",   "client",   "slaveof",
    "save",     "bgsave",   "lastsave", "flushdb",
    "flushall", "monitor",  "time", "slowlog",
    "info",                                             -- server
    "publish",                                          -- publish
}


local sub_commands = {
    "subscribe", "psubscribe"
}

local unsub_commands = {
    "unsubscribe", "punsubscribe"
}

local defaultRedisReadOvertime = 15

local class = class
local Credis = class("redis", CasyncClient)

local sub = string.sub
local find = string.find
local tostring = tostring
local error = error
local print = print
local ipairs = ipairs
local tonumber = tonumber
local unpack = unpack
local type = type
local format = string.format
local split = pystring.split
local concat = table.concat
local insert = table.insert
local running = coroutine.running
local yield = coroutine.yield
local liteAssert = system.liteAssert
local getIp = workVar.getIp
local connectAdd = workVar.connectAdd
local connectDel = workVar.connectDel

local function packCmd(cmd, ...)
    local args = {...}
    local res = {}
    res[1] = format("*%d", #args + 1)
    res[2] = format("$%s", #cmd)
    res[3] = cmd
    
    local c = 3
    for _, arg in ipairs(args) do
        c = c + 1
        res[c] = format("$%d", #arg)
        c = c + 1
        res[c] = arg
    end
    c = c + 1
    res[c] = ""
    return concat(res, "\r\n")
end


function Credis:_init_(tReq, host, port, tmo, pswd)
    local ip

    ip, port = getIp(host), port or 6379
    if not ip then
        return nil
    end
    tmo = tmo or 10

    local tPort = {family=psocket.AF_INET, addr=ip, port=port}
    CasyncClient._init_(self, tReq, tReq.fd, tPort, tmo)

    for _, cmd in ipairs(common_cmds) do
        self[cmd] = function(obj, ...)
            local s = packCmd(cmd, ...)
            local res, msg = obj:send(s)
            return res, msg
        end
    end
    self._pswd = pswd
end

function Credis:send(s)
    if self._status == 1 then
        return self:_waitData(s)
    end
    return nil, "not connect."
end

local function checkCRLF(s)
    local start = find(s, "\r\n")
    if start then
        return start
    end
    return nil
end

local function waitBlock(s, fread)
    while true do
        local start = checkCRLF(s)
        if start then
            return s, start
        end
        local add = fread(defaultRedisReadOvertime)
        if add then
            s = concat({s, add})
        else
            return nil
        end
    end
end

local function waitLength(s, fread, length)
    while #s < length do
        local add = fread(defaultRedisReadOvertime)
        if add then
            s = concat({s, add})
        else
            return nil
        end
    end
    return s
end

local syms_tab

local function exec_sym(s, fread)
    local code = sub(s, 1, 1)
    local func = syms_tab[code]
    if func then
        return func(sub(s, 2), fread)
    end
    return nil
end

local function prefixDollar(s, fread) -- $
    local start
    s, start = waitBlock(s, fread)
    if s then
        local size, rest = unpack(split(s, "\r\n", 1))
        size = tonumber(size)
        if size and size > 0 then
            s = waitLength(rest, fread, size + 2)
            if s then
                return sub(s, 1, size), sub(s, size + 3)
            end
        end
    end
    return nil
end

local function prefixPlus(s, fread) -- + string
    local start
    s, start = waitBlock(s, fread)
    if s then
        return sub(s, 1, start - 1), sub(s, start + 2)
    end
    return nil
end

local function prefixMinus(s, fread)  -- -  error
    local start
    s, start = waitBlock(s, fread)
    if s then
        return sub(s, 1, start - 1), sub(s, start + 2)
    end
    return nil
end

local function prefixColon(s, fread)  -- :  number
    local start
    s, start = waitBlock(s, fread)
    if s then
        local num = tonumber(sub(s, 1, start - 1))
        return num, sub(s, start + 2)
    end
end

local function prefixStar(s, fread)    -- *
    local start
    s, start = waitBlock(s, fread)
    if s then
        local num, rest = unpack(split(s, "\r\n", 1))
        num = tonumber(num)
        local cells = {}
        local cell
        for i = 1, num do
            cell, rest = prefixDollar(sub(rest, 2), fread)
            cells[i] = cell
        end
        return cells, rest
    end
    return nil
end

local function prefixUnderline(s, fread)   -- _ null
    local start
    s, start = waitBlock(s, fread)
    if s then
        return "nil", sub(s, start + 2)
    end
    return nil
end

local function prefixComma(s, fread)       -- , double
    local start
    s, start = waitBlock(s, fread)
    if s then
        local num = tonumber(sub(s, 1, start - 1))
        return num, sub(s, start + 2)
    end
    return nil
end

local function prefixPound(s, fread)       -- # boolean
    local start
    s, start = waitBlock(s, fread)
    if s then
        s = sub(s, 1, 1)
        if s == 't' then
            return true, sub(s, start + 2)
        else
            return false, sub(s, start + 2)
        end
    end
    return nil
end

local function prefixParen(s, fread)       -- (  big number
    local start
    s, start = waitBlock(s, fread)
    if s then
        return sub(s, 1, 1), sub(s, start + 2)
    end
end

local function prefixExclamation(s, fread)     -- ! Blob error
    local start
    s, start = waitBlock(s, fread)
    if s then
        local size, rest = unpack(split(s, "\r\n", 1))
        size = tonumber(size)
        s = waitLength(rest, fread, size + 2)
        if s then
            return sub(s, 1, size), sub(s, size + 3)
        end
    end
    return nil
end

local function prefixPercent(s, fread)     -- % for map
    local start
    s, start = waitBlock(s, fread)
    if s then
        local num, rest = unpack(split(s, "\r\n", 1))
        num = tonumber(num)
        local cells = {}
        local k, v
        for i = 1, num do
            k, rest = exec_sym(rest, fread)
            v, rest = exec_sym(rest, fread)
            if k and v then
                cells[k] = v
            else
                return nil
            end
        end
        return cells, rest
    end
    return nil
end

local function prefixTilde(s, fread)       -- ~ for list
    local start
    s, start = waitBlock(s, fread)
    if s then
        local num, rest = unpack(split(s, "\r\n", 1))
        num = tonumber(num)
        local cells = {}
        local cell
        for i = 1, num do
            cell, rest = exec_sym(rest, fread)
            if cell then
                cells[i] = cell
            else
                return nil
            end
        end
        return cells, rest
    end
    return nil
end

local function prefixVerticalBar(s, fread)   -- | equal %
    return prefixPercent(s, fread)
end

local function prefixMoreThan(s, fread)    -- > equal *
    return prefixStar(s, fread)
end

syms_tab = {
    ["$"] = prefixDollar,
    ["+"] = prefixPlus,
    ["-"] = prefixMinus,
    [":"] = prefixColon,
    ["*"] = prefixStar,
    ["_"] = prefixUnderline,
    [","] = prefixComma,
    ["#"] = prefixPound,
    ["("] = prefixParen,
    ["!"] = prefixExclamation,
    ["%"] = prefixPercent,
    ["~"] = prefixTilde,
    ["|"] = prefixVerticalBar,
    [">"] = prefixMoreThan,
}

local function read_reply(fread)
    local s, _ = fread()
    if s then
        return exec_sym(s, fread)
    end
    return nil
end

local function read_replies(fread)
    local cells, cell, c = {}, nil, 1
    local s, _ = fread()
    while s do
        cell, s = exec_sym(s, fread)
        cells[c] = cell
        c = c + 1
    end
    return cells
end

function Credis:pipeline()
    local pipeRedis = {}
    pipeRedis._cmds = {}
    for _, cmd in ipairs(common_cmds) do
        pipeRedis[cmd] = function(obj, ...)
            local s = packCmd(cmd, ...)
            insert(pipeRedis._cmds, s)
        end
    end
    pipeRedis.send = function(obj)
        return self:send(obj._cmds)
    end
    return pipeRedis
end

function Credis:_setup(fd, tmo)
    local beaver = self._beaver
    local co = self._coWake
    local status, res, msg
    local e, t, lastType
    local maxLen = 4 * 1024 * 1024

    connectAdd("redis", fd, running())
    beaver:co_set_tmo(fd, tmo)
    status, e = self:cliConnect(fd, tmo)

    if status == 1 and e == nil then -- host closed
        self._status = 0
        self:wake(co, nil)
    end
    if type(e) == "boolean" then  -- for unix socket connect direct may return boolean true.
        e = nil
    end

    if self._pswd then
        local s = packCmd("auth", self._pswd)
        res, msg = beaver:write(fd, s)
        if not res then
            print("redis auth writeerror.", msg)
            self._status = 0
            self:wake(co, nil)
            return
        end

        res, msg = beaver:read(fd, 16)
        if not res then
            print("redis auth readerror.", msg)
            self._status = 0
            self:wake(co, nil)
            return
        end
        if type(res) ~= "string" then
            print("redis auth readerror.", msg)
            self._status = 0
            self:wake(co, nil)
            return
        end
        if sub(res, 1, 3) ~= "+OK" then
            print("redis auth error.", sub(res, 1, 3))
            self._status = 0
            self:wake(co, nil)
            return
        end
    end

    local clear
    while status == 1 do
        if not e then
            e = yield()
        end
        local _ = clear and clear()
        t = type(e)
        if t == "string" then -- single cmd
            res, msg = beaver:write(fd, e)
            if not res then  -- for write failed.
                print("redis write error.", msg)
                self._status = 0
                self:wake(co, nil)
                break
            end
            e = nil
            clear = beaver:timerWait(fd)
            lastType = "string"
        elseif t == "table" then
            local s = concat(e)  -- contract all syms.
            res = beaver:write(fd, s)
            if not res then
                print("redis write error.", msg)
                self._status = 0
                self:wake(co, nil)
                break
            end
            e = nil
            clear = beaver:timerWait(fd)
            lastType = "table"
        elseif t == "nil" then  -- host closed
            print("host closed.")
            self._status = 0
            self:wake(co, nil)
            break
        elseif t == "number" then -->time out 
            if e > 0 then
                self._status = 0
                self:wake(co, nil)
                break
            end
            e = nil
        elseif t == "cdata" then  -- read event.
            local ev_in, ev_close = e.ev_in, e.ev_close
            if ev_in > 0 then
                clear = nil -- clear timerWait.
                local fread = beaver:reads(fd, maxLen, tmo/2)
                if lastType == "table" then
                    res = read_replies(fread)
                else
                    res = read_reply(fread)
                end
                if not res then  -- remote close or time out.
                    self._status = 0
                    self:wake(co, nil)
                    break
                end

                local r = self:wake(co, res)  -- from next working.

                e = r
                t = type(e)
                if t == "cdata" then -->upstream need to close.
                    liteAssert(ev_close > 0)
                    self:wake(co, nil)  -->let upstream to do next working.
                    break
                elseif t == "number" then  -->upstream reuse connect
                    if e > 0 then
                        self._status = 0
                        self:wake(co, nil)
                        break
                    end
                    e = nil
                elseif t == "nil" then -->upstream need to close.
                    self._status = 0
                    self:wake(co, nil)  -->let upstream to do next working.
                    break
                elseif t == "string" or t == "table" then
                    e = e
                else
                    error(format("redis type: %s, not support, , unknown error.", t))
                end
            elseif ev_close > 0 then
                self._status = 0
                self:wake(co, nil)
                break
            else
                print("IO Error.")
                self._status = 0
                break
            end
        else
            error(format("redis loop type: %s, not support, , unknown error.", t))
        end
    end

    self._status = 0  -- closed
    self:stop()
    connectDel("redis", fd)
end

return Credis
