local require = require

local posix = require("posix")
local unistd = require("posix.unistd")
local workVar = require("module.workVar")
local pystring = require("cpystring")
local sio = require("common.sio")
local system = require("common.system")
local bit = require("bit")

local create = coroutine.create
local resume = coroutine.resume
local yield = coroutine.yield
local coReport =system.coReport
local bor = bit.bor
local split = pystring.split
local partition = pystring.partition
local rpartition = pystring.rpartition
local open = posix.open
local close = posix.close
local insert = table.insert
local concat = table.concat
local ipairs = ipairs
local date = os.date
local format = string.format
local wlog = workVar.log
local writes = sio.writes
local fileSize = sio.fileSize
local gzips = sio.gizps
local exist = sio.exist
local rename = sio.rename
local io_open = io.open
local truncate = unistd.truncate
local print = print
local error = error

local M = {}
local levels = {"trace", "debug", "info", "warn", "error", "fatal"}
local logLevel = 3  -- default is info
local logPattern = "%l %d: %m"
local logFmt
local logOutFunc
local coLog

local function rotataGz(head, seq, rotate)
    if seq < rotate then
        rotataGz(head, seq + 1, rotate)
        local current = head .. "." .. seq .. ".gz"
        local nextw = head .. "." .. seq + 1 .. ".gz"
        if exist(current) then
            rename(current, nextw)
        end
    end
end

local function rotateLog(path, rotate)
    local head, _, _ = rpartition(path, ".")
    rotataGz(head, 1, rotate)
    local f = io_open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local gz = head .. ".1.gz"
        local fd = open(gz, bor(posix.O_CREAT, posix.O_WRONLY), "rw-rw-r--")
        if fd < 0 then
            error("open log file failed")
        end
        writes(fd, gzips(content, path))
        close(fd)
    end

    truncate(path, 0)
    return open(path, posix.O_WRONLY, "rw-rw-r--")
end

local function fileOut(filePath, maxLogSize, rotate)
    local size = fileSize(filePath)
    local fd

    if size < 0 then
        fd = open(filePath, bor(posix.O_CREAT, posix.O_WRONLY), "rw-rw-r--")
        size = 0
    elseif size > maxLogSize then
        fd = rotateLog(filePath, rotate)
        size = 0
    else
        fd = open(filePath, bor(posix.O_WRONLY, posix.O_APPEND))
    end
    
    if fd < 0 then
        error("open log file failed")
    end
    return function(logs)
        size = size + writes(fd, logs)
        if (size > maxLogSize) then
            close(fd)
            fd = rotateLog(filePath, rotate)
            size = 0
        end
    end
end

local function setupLogOut(out, maxLogSize, rotate)
    if type(out) == "number" then
        if out == 1 then
            return function(logs)
                io.stdout:write(concat(logs))
            end
        elseif out == 2 then
            return function(logs)
                io.stderr:write(concat(logs))
            end
        end
    elseif type(out) == "string" then
        return fileOut(out, maxLogSize, rotate)
    else
        error("out must be number or string")
    end
end

-- worker log output write to master pipe
local function workerOut(level, msg)
    wlog(level, msg)
end

--- master log output write to master pipe
--- @param vec table, log level
--- @return nil
function M.mlog(vec)
    logOutFunc(vec)
end

local function _log(level, fmt, ...)
    if level < logLevel or #fmt == 0 then
        return
    end
    local msg = format(fmt, ...)
    local res, m = resume(coLog, logFmt(level, msg))
    coReport(coLog, res, m)
end

--- 
--- @param fmt string, log format
--- @param ... any, log args
--- @return nil
function M.trace(fmt, ...)
    _log(1, fmt, ...)
end

--- 
--- @param fmt string, log format
--- @param ... any, log args
--- @return nil
function M.debug(fmt, ...)
    _log(2, fmt, ...)
end

--- 
--- @param fmt string, log format
--- @param ... any, log args
--- @return nil
function M.info(fmt, ...)
    _log(3, fmt, ...)
end

--- 
--- @param fmt string, log format
--- @param ... any, log args
--- @return nil
function M.warn(fmt, ...)
    _log(4, fmt, ...)
end

--- 
--- @param fmt string, log format
--- @param ... any, log args
--- @return nil
function M.error(fmt, ...)
    _log(5, fmt, ...)
end

--- 
--- @param fmt string, log format
--- @param ... any, log args
--- @return nil
function M.fatal(fmt, ...)
    _log(6, fmt, ...)
end

local function parseSeg(pattern, seg, arrs, index)
    local left, Seg, right = partition(pattern, seg)
    if #Seg > 0 then
        if #left > 0 then
            arrs[index] = left
            insert(arrs, index + 1, Seg)
            if #right then
                insert(arrs, index + 2, right)
            end
        else
            arrs[index] = Seg
            if #right then
                insert(arrs, index + 1, right)
            end
        end
        return true
    else
        return false
    end
end

-- find index of seg in fmt
local function findIndex(fmt, seg)
    for i, s in ipairs(fmt) do
        if s == seg then
            return i
        end
    end
    return -1
end

-- returns log format function
-- like "%l %t: %m"  -- %l: level, %d: time, %m: message. just once
local function setupFormat(pattern)
    if #pattern == 0 then  -- none
        return function(level, msg) return {} end
    end
    local fmt = {pattern}
    local segs = {"%l", "%t", "%m"}
    for i = 1, #segs do
        for j = 1, #fmt do
            if parseSeg(fmt[j], segs[i], fmt, j) then
                break
            end
        end
    end

    local levelIndex = findIndex(fmt, "%l")
    local timeIndex = findIndex(fmt, "%t")
    local msgIndex = findIndex(fmt, "%m")
    fmt[#fmt + 1] = "\n"

    return function (level, msg)
        if timeIndex > 0 then
            fmt[timeIndex] = date("%Y-%m-%d %H:%M:%S")
        end
        if levelIndex > 0 then
            fmt[levelIndex] = levels[level]
        end
        if msgIndex > 0 then
            fmt[msgIndex] = msg
        end
        return fmt
    end
end

local function logLoop()
    while true do
        local vec = yield()
        logOutFunc(vec)
    end
end

--- init log for global settings, do not call this in worker
--- --
--- @param islocal boolean, true for master direct write, false for worker remote write
--- @param level number, log levels
--- @param pattern string, log pattern, default is "%l %t: %m"  -- %l: level, %d: time, %m: message
--- @param out string? or number, log output, if is number, then it is file descriptor, should be 1(stdout) or 2(stderr), if is string, then it is file path
--- @param maxLogSize? number, max log size, default is 10M, unit is kilobyte， just for file
--- @param rotate? number, log rotate, default is 10, unit is time, just for file
--- @return nil
function M._init(islocal, level, pattern, out, maxLogSize, rotate)
    logLevel = level or logLevel
    logPattern = pattern or logPattern
    logFmt = setupFormat(logPattern)
    if islocal then
        logOutFunc = setupLogOut(out, maxLogSize, rotate)
    else
        logOutFunc = workerOut
    end
    coLog = create(logLoop)
    local res, msg = resume(coLog)
    coReport(coLog, res, msg)
end

return M