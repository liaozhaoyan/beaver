---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/6 7:53 PM
---

require("eclass")

local psocket = require("posix.sys.socket")
local unistd = require("posix.unistd")
local pystring = require("pystring")
local CasyncBase = require("async.asyncBase")

local CasyncDns = class("asyncDns", CasyncBase)

local function lookup_server()
    local f = io.open("/etc/resolv.conf")
    local server
    for line in f:lines() do
        if pystring.startswith(line, "nameserver") then
            local res = pystring.split(line)
            server = res[2]
            break
        end
    end

    f:close()
    return server
end

function CasyncDns:_init_(beaver)
    self._serverIP = lookup_server()
    assert(self._serverIP)

    local fd, err, errno = psocket.socket(psocket.AF_INET, psocket.SOCK_DGRAM, 0)
    assert(fd, err)


    CasyncBase._init_(self, beaver, fd, 10)  -- accept never overtime.
end

local function packQuery(domain)
    local cnt = 0
    local queries = {}
    local head = string.char(
            0x12, 0x34, -- Query ID
            0x01, 0x00, -- Standard query
            0x00, 0x01, -- Number of questions
            0x00, 0x00, -- Number of answers
            0x00, 0x00, -- Number of authority records
            0x00, 0x00  -- Number of additional records
    )
    cnt = cnt + 1
    queries[cnt] = head

    local names = pystring.split(domain, ".")
    for _, name in ipairs(names) do
        cnt = cnt + 1
        queries[cnt] = string.char(string.len(name))
        cnt = cnt + 1
        queries[cnt] = name
    end
    cnt = cnt + 1
    local tail = string.char(
            0x00, -- End of domain name
            0x00, 0x01, -- Type A record
            0x00, 0x01 -- Class IN
    )
    queries[cnt] = tail

    local query = table.concat(queries)
    return query
end

function CasyncDns:_setup(fd, tmo)
    local beaver = self._beaver
    local serverIP = self._serverIP
    local res, len, err, errno
    local tDist = {family=psocket.AF_INET, addr=serverIP, port=53}

    while true do
        beaver:co_set_tmo(fd, -1)
        local co, domain = coroutine.yield()

        local query = packQuery(domain)
        len, err, errno = psocket.sendto(fd, query, tDist)
        if not len then
            print(err, errno)
            coroutine.resume(co, nil)
            break
        end

        beaver:co_set_tmo(fd, tmo)
        res, err, errno = beaver:read(fd, 512)
        if not res then
            print(err, errno)
            coroutine.resume(co, nil)
            break
        else
            local ip = string.format("%d.%d.%d.%d", string.byte(res, -4, -1))
            coroutine.resume(co, ip)
        end
    end
    self:stop()
    unistd.close(fd)
end

function CasyncDns:request(domain)
    local co = coroutine.running()
    coroutine.resume(self._co, co, domain)
    return coroutine.yield()
end

return CasyncDns
