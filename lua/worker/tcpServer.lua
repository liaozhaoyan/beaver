require("eclass")

local CasyncBase = require("async.asyncBase")
local workVar = require("module.workVar")
local sockComm = require("common.sockComm")

local class = class
local CtcpServer = class("tcpServer", CasyncBase)

local pairs = pairs
local type = type
local print = print
local running = coroutine.running
local yield = coroutine.yield
local pcall = pcall
local srvSslHandshake = sockComm.srvSslHandshake

function CtcpServer:_init_(beaver, fd, bfd, addr, conf, inst, ctx)
    self._beaver = beaver
    self._inst = inst

    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    self._ctx = ctx

    CasyncBase._init_(self, beaver, fd, 10)
end

function CtcpServer:_setup(fd, tmo)
    local beaver = self._beaver
    local module = self._conf.func

    local inst = self._inst
    local ret = 1
    local ctx = self._ctx

    beaver:co_set_tmo(fd, tmo)
    workVar.clientAdd(module, self._bfd, fd, running(), self._addr)
    if ctx then
        ret = srvSslHandshake(beaver, fd, ctx)
    end

    if ret == 1 then
        if inst.accept then  -- first write
            local ok, res = pcall(inst.accept, inst, beaver, fd)
            if not ok then
                print("tcpServer accept error: ", res)
                goto stop_client
            end
        end
        while true do
            local e = yield()
            if type(e) ~= "cdata" or e.ev_in < 1 then
                break
            end
            local ok, res = pcall(inst.read, inst, beaver, fd)
            if not ok then
                print("tcpServer read error: ", res)
                break
            end
            if not res then  -- read error
                break
            end
        end
    end
    ::stop_client::
    if inst.close then
        local ok, res = pcall(inst.close, inst, beaver, fd)
        if not ok then
            print("tcpServer close error: ", res)
        end
    end

    self:stop()
    workVar.clientDel(module, fd)
end

return CtcpServer