---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/6 7:53 PM
---

require("eclass")

local system = require("common.system")
local psocket = require("posix.sys.socket")
local pystring = require("pystring")
local sockComm = require("common.sockComm")
local CasyncBase = require("async.asyncBase")

local class = class
local CasyncDns = class("asyncDns", CasyncBase)

local mathHuge = math.huge
local pairs = pairs
local ipairs = ipairs
local time = os.time
local print = print
local io_open = io.open
local liteAssert = system.liteAssert
local coReport = system.coReport
local yield = coroutine.yield
local resume = coroutine.resume
local startswith = pystring.startswith
local split = pystring.split
local new_socket = psocket.socket
local psendto = psocket.sendto
local char = string.char
local len = string.len
local format = string.format
local byte = string.byte
local concat = table.concat
local insert = table.insert
local error = error
local isIPv4 = sockComm.isIPv4

local freshDns
local wakeDns

local function lookupServer()
    local f = io_open("/etc/resolv.conf")
    local server
    liteAssert(f, "dns config not found.")
    for line in f:lines() do
        if startswith(line, "nameserver") then
            local res = split(line)
            server = res[2]
            break
        end
    end

    f:close()
    return server
end

local function lookupLocal(path)
    local res = {}
    path = path or "/etc/hosts"
    local f = io_open(path)
    liteAssert(f, "dns config not found.")
    for line in f:lines() do
        local ss = split(line)
        local ip = ss[1]
        if isIPv4(ip) then
            for i =2, #ss do
                res[ss[i]] = {ip, mathHuge}
                print(ip, ss[i])
            end
        end
    end
    f:close()
    return res
end

function CasyncDns:_init_(beaver, fresh, wake)
    self._serverIP = lookupServer()
    liteAssert(self._serverIP)

    local fd, err, errno = new_socket(psocket.AF_INET, psocket.SOCK_DGRAM, 0)
    liteAssert(fd, err)

    self._requesting = {}  -- domain -> fid, coId
    freshDns = fresh
    wakeDns = wake

    local res = lookupLocal()
    for k, v in pairs(res) do
        freshDns(k, v)
    end

    CasyncBase._init_(self, beaver, fd, 10)  -- accept never overtime.
end

local function packQuery(domain)
    local cnt = 0
    local queries = {}
    local head = char(
            0x12, 0x34, -- Query ID
            0x01, 0x00, -- Standard query
            0x00, 0x01, -- Number of questions
            0x00, 0x00, -- Number of answers
            0x00, 0x00, -- Number of authority records
            0x00, 0x00  -- Number of additional records
    )
    cnt = cnt + 1
    queries[cnt] = head

    local names = split(domain, ".")
    for _, name in ipairs(names) do
        cnt = cnt + 1
        queries[cnt] = char(len(name))
        cnt = cnt + 1
        queries[cnt] = name
    end
    cnt = cnt + 1
    local tail = char(
            0x00, -- End of domain name
            0x00, 0x01, -- Type A record
            0x00, 0x01 -- Class IN
    )
    queries[cnt] = tail

    local query = concat(queries)
    return query
end

local function wakesDns(requesting, domain, ip)
    local requests = requesting[domain]
    for _, req in ipairs(requests) do  -- req contains {fid, coId}
        wakeDns(domain, ip, req[1], req[2])
    end
    requesting[domain] = nil
end

function CasyncDns:_setup(fd, tmo)
    local res
    local beaver = self._beaver
    local serverIP = self._serverIP
    local size, err, errno
    local tDist = {family=psocket.AF_INET, addr=serverIP, port=53}
    local failed = 0

    while true do
        beaver:co_set_tmo(fd, -1)
        local domain, tVar = yield()   -- tVar contains {fid, coId}

        local query = packQuery(domain)
        size, err, errno = psendto(fd, query, tDist)
        if size then
            beaver:co_set_tmo(fd, tmo)
            res, err, errno = beaver:read(fd, 512)
            local ip
            if res then
                ip = format("%d.%d.%d.%d", byte(res, -4, -1))
                freshDns(domain, {ip, time()})
                failed = 0
            else
                print("dns read fialed.", err, errno)
                failed = failed + 1
            end
            wakesDns(self._requesting, domain, ip)
        else
            print("dns sentto fialed.", err, errno)
            wakesDns(self._requesting, domain, nil)
            failed = failed + 1
        end

        if failed > 100 then
            break
        end
    end
    self:stop()
    error("dns failed.")
end

function CasyncDns:request(domain, tVar) -- tVar contains {fid, coId}
    if self._requesting[domain] then
        insert(self._requesting[domain], tVar)
        return
    end

    self._requesting[domain] = {tVar}
    local res, msg
    res, msg = resume(self._co, domain, tVar)
    coReport(self._co, res, msg)
end

return CasyncDns
