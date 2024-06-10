require("eclass")
local system = require("common.system")
local asyncClient = require("async.asyncClient")
local cffi = require("beavercffi")
local c_type, c_api = cffi.type, cffi.api

local class = class
local cliBase = class("cliBase", asyncClient)

local print = print
local type = type
local liteAssert = system.liteAssert
local yield = coroutine.yield
local c_api_b_close = c_api.b_close

function cliBase:_init_(beaver, tPort, tmo)
    tmo = tmo or 10
    local tReq = {
        beaver = beaver,
    }
    asyncClient._init_(self, tReq, nil, tPort, tmo)
    -- asyncClient will yield for connected
end

function cliBase:echo(s)
    local res, msg = self:_waitData(s)
    liteAssert(res, msg)
    if type(res) ~= "string" then
        return nil
    end
    return res
end

function cliBase:_setup(fd, tmo)
    local beaver = self._beaver
    local co = self._coWake  -- set in asyncClient
    local status, res
    local e

    status, e = self:cliConnect(fd, tmo)

    while status == 1 do
        if not e then
            e = yield()
        end
        local t = type(e)
        if t == "string" then -- has data to send
            beaver:co_set_tmo(fd, tmo)
            res = beaver:write(fd, e)
            if not res then
                break
            end
            e = nil
            beaver:co_set_tmo(fd, -1)
        elseif t == "nil" then  -- host closed
            self:wake(co, nil)
            break
        else  -- read event.
            if e.ev_close > 0 then
                break
            elseif e.ev_in > 0 then
                local s = beaver:read(fd, 256)
                e = self:wake(co, s)
                t = type(e)
                if t == "cdata" then -->upstream need to close.
                    liteAssert(e.ev_close > 0)
                    self:wake(co, nil)  -->let upstream to do next working.
                    break
                elseif t == "number" then  -->upstream reuse connect
                    e = nil
                end
            else
                print("IO Error.")
                break
            end
        end
    end

    self._status = 0  -- closed
    self:stop()
    c_api_b_close(fd)
end

return cliBase
