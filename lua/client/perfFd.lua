local require = require
require("eclass")
local class = class
local system = require("common.system")
local CasyncBase = require("async.asyncBase")
local CperfFd = class("perfFd", CasyncBase)

local coRerport = system.coReport
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local type = type

-- cb is read read callback function.
-- cbIn: callback for fd in event, arg 1 is fd, return -1 will exit.
-- cbEvent: callback for fd timeout, close event, arg 1 is fd, arg 2: 0 for timeout(return not nil for hold.), 1 for close. 
function CperfFd:_init_(beaver, fd, cbIn, cbEvent, tmo)
    self._cb = cbIn
    self._cbEvent = cbEvent
    CasyncBase._init_(self, beaver, fd, tmo)
end

function CperfFd:close()
    local co = self._co
    if status(co) == "normal" then
        self._beaver:co_yield()  -- release callchain from _setup function
    end

    if status(co) == "suspended" then
        local res, msg = resume(co, nil)  -- close setup.
        coRerport(co, res, msg)
    end
end

function CperfFd:eventInfo(e)
    return {
        [0] = "time out event, check tmo args.",
        [1] = "fd closed."
    }
end

function CperfFd:_setup(fd, tmo)
    local beaver = self._beaver
    beaver:co_yield()

    beaver:co_set_tmo(fd, tmo)

    local cb = self._cb
    local cbEvent = self._cbEvent

    local e, t
    local clear = tmo > 0 and beaver:timerWait(fd)
    while true do
        e = yield()
        local _ = clear and clear()  -- clear timer.
        t = type(e)
        if e == nil then  -- host close.
            break
        elseif t == "number" then -- over timer.
            if e > 0 then
                local ret = cbEvent and cbEvent(fd, 0)  -- call wait over time function
                if not ret then  -- if return not nil then will hold timeout event.
                    break
                end
            end
        elseif t == "cdata" then
            local ev_in, ev_close = e.ev_in, e.ev_close
            if ev_in > 0 then
                if cb(fd) < 0 then
                    break
                end
                clear = tmo > 0 and beaver:timerWait(fd)
            end
            if ev_close > 0 then
                local _ = cbEvent and cbEvent(fd, 1)  -- 1 file close.
                break
            end
        end
    end
    self:stop()  -- close fd
end

return CperfFd
