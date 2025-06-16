local require = require

local workVar = require("module.workVar")

local msleep = workVar.msleep
local wait = workVar.wait

local M = {}

--- sleep milliseconds
--- @param ms number, milliseconds
--- @return number
function M.msleep(ms)
    return msleep(ms)
end

--- coroutine sleep seconds
--- @param s number, seconds
--- @return number
function M.sleep(s)
    return msleep(s * 1000)
end

--- coroutine wait milliseconds
--- @param co coroutine, coroutine
--- @param ms number, milliseconds
function M.wait(co, ms)
    wait(co, ms)
end

return M
