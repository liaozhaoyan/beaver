require("eclass")

local CasyncBase = require("async.asyncBase")

local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local CservLoop = class("servLoop", CasyncBase)

function CservLoop:_init_(beaver, fd, bfd, addr, conf)
    self._beaver = beaver
    local tmo = conf.tmo or 10
    self._bfd = bfd
    self._addr = addr
    self._conf = conf
    CasyncBase._init_(self, beaver, fd, tmo)
end

function CservLoop:_setup(fd, tmo)
    local beaver = self._beaver

    while true do
        beaver:co_set_tmo(fd, -1)
        local s = beaver:read(fd)
        if not s then
            break
        end
        beaver:co_set_tmo(fd, tmo)
        local res = beaver:write(fd, s)
        if not res then
            break
        end
    end
    self:stop()
    c_api.b_close(fd)
end

return CservLoop
