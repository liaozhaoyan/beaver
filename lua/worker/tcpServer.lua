require("eclass")

local system = require("common.system")
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
local systemPcall = system.pcall
local lastError = system.lastError
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
    local ctxt = {}

    if ret == 1 then
        if inst.accept then  -- first write
            local ok, _ = systemPcall(inst.accept, inst, beaver, fd, ctxt)
            if not ok then
                print("tcpServer accept error: ", lastError())
                goto stop_client
            end
        end
        while true do
            local e = yield()
            if type(e) ~= "cdata" or e.ev_in < 1 then
                break
            end
            local ok, res = systemPcall(inst.read, inst, beaver, fd, ctxt)
            if not ok then
                print("tcpServer read error: ", lastError())
                break
            end
            if not res then  -- read error
                break
            end
        end
    end
    ::stop_client::
    if inst.close then
        local ok, _ = systemPcall(inst.close, inst, beaver, fd, ctxt)
        if not ok then
            print("tcpServer close error: ", lastError())
        end
    end

    self:stop()
    workVar.clientDel(module, fd)
end

return CtcpServer