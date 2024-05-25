---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/1 11:40 PM
---

require("eclass")

local class = class
local CasyncBase = class("asyncBase")

function CasyncBase:_init_(beaver, fd, tmo)
    tmo = tmo or -1
    self._fd = fd
    self._beaver = beaver

    self._co = beaver:co_add(self, self._setup, fd, tmo)  -- setup should apply for children class
end

function CasyncBase:stop()
    self._beaver:co_exit(self._fd)
end

return CasyncBase