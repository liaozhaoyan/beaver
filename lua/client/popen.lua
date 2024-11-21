local require = require
require("eclass")
local class = class
local CperfFd = require("client.perfFd")
local workVar = require("module.workVar")
local posix = require("posix")
local pwait = require("posix.sys.wait")
local signal = require("posix.signal")
local Cpopen = class("popen", CperfFd)

local WNOHANG = pwait.WNOHANG
local WUNTRACED = pwait.WUNTRACED
local popen = posix.popen
local waitpid = pwait.wait
local kill = signal.kill
local ipairs = ipairs
local msleep = workVar.msleep

-- cmds: table, {"ls", "-l"}
-- cbIn: callback for fd in event, arg 1 is fd, return -1 will exit.
-- cbEvent: callback for fd timeout, close event, arg 1 is fd, arg 2: 0 for timeout(return not nil for hold.), 1 for close. 
function Cpopen:_init_(beaver, cmds, cbIn, cbEvent)
    self._pfd = popen(cmds, "r")
    if self._pfd then
        CperfFd._init_(self, beaver, self._pfd.fd, cbIn, cbEvent)
    end
end

-- return: child pids {{pid, stat, code}}
function Cpopen:wait()
    local rets = {}
    if self._pfd then
        self._beaver:mod_fd(self._pfd.fd, -2)
        -- remove fd from epoll at first, to avoid epoll close fd hangup event.
        msleep(5)  --need sleep for waitpid exit.
        for i, pid in ipairs(self._pfd.pids) do
            local _pid, stat, code = waitpid(pid, WNOHANG)
            if stat == "running" then
                kill(pid, 9)
                msleep(100)
                _pid, stat, code = waitpid(pid, WNOHANG)
            end
            rets[i] = {_pid, stat, code}
        end
        self._beaver:mod_fd(self._pfd.fd, -3)
        -- add back to epoll, then will remove it by beaverIO:remove(fd)
    end
    self._pfd = nil
    return rets
end

function Cpopen:stop()
    if self._pfd then
        -- do not use pclose, beaver will close fd in self:stop function.
        self:wait()
    end
    CperfFd.stop(self)
end

return Cpopen
