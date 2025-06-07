local buffer = require("string.buffer")

local format = string.format
local rep = string.rep
local byte = string.byte
local io_write = io.write
local ffi = require("ffi")

local function hexdump(buf)
    for Byte=1, #buf, 16 do
        local chunk = buf:sub(Byte, Byte+15)
        io_write(format('%08X  ',Byte-1))
        chunk:gsub('.', function (c) io_write(format('%02X ',byte(c))) end)
        io_write(rep(' ',3*(16-#chunk)))
        io_write(' ',chunk:gsub('%c','.'),"\n")
    end
end

local req = {
    "pipeCtrlReg",
    ffi.new("unsigned long", 6),
    ffi.new("unsigned long", 7),
}

hexdump(buffer.encode(req))

req = {
    "masterExit"
}
hexdump(buffer.encode(req))
