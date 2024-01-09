---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/7 11:06 AM
---

require("eclass")
local unistd = require("posix.unistd")
local system = require("common.system")
local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")

local CdnsReq = class("CdnsReq", CasyncBase)

function CdnsReq:_init_(beaver, fd, bfd, addr, conf, tmo)
    self._beaver = beaver
    tmo = tmo or 10
    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    CasyncBase._init_(self, beaver, fd, tmo)
end

function CdnsReq:_setup(fd, tmo)
    local beaver = self._beaver
    local module = self._conf.func

    workVar.clientAdd(module, self._bfd, fd, coroutine.running(), self._addr)

    repeat
        beaver:co_set_tmo(fd, -1)
        local s = beaver:read(fd)
        if not s then
            break
        end

        local domain, ip = workVar.dnsReq(s)
        assert(domain == s, "bad echo.")

        beaver:co_set_tmo(fd, tmo)
        local res = beaver:write(fd, domain .. ":" .. ip)
        if not res then
            break
        end
    until false

    self:stop()
    unistd.close(fd)
    workVar.clientDel(module, fd)
end

return CdnsReq