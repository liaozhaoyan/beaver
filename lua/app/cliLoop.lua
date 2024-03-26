require("eclass")

local CasyncBase = require("async.asyncBase")
local sockComm = require("common.sockComm")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local CcliLoop = class("cliLoop", CasyncBase)

function CcliLoop:_init_(beaver, fd, tPort, tmo)
    self._beaver = beaver
    self._tPort = tPort
    self._toWake = coroutine.running()
    tmo = tmo or 10
    CasyncBase._init_(self, beaver, fd, tmo)
    coroutine.yield()
end

function CcliLoop:_setup(fd, tmo)
    local res
    local beaver = self._beaver

    beaver:co_set_tmo(fd, tmo)  -- set connect timeout
    res = sockComm.connect(fd, self._tPort, beaver)
    beaver:co_set_tmo(fd, -1)   -- back
    assert(res == 1, "connect to uni failed.")

    for i = 1, 5 do
        res = beaver:write(fd, "hello.")
        if not res then
            break
        end

        local s = beaver:read(fd)
        if not s then
            break
        end
        assert(s == "hello.")
    end
    self:stop()
    c_api.b_close(fd)
    coroutine.resume(self._toWake)
end

return CcliLoop