local require = require

local pystring = require("pystring")
local pywith = pystring.with
local concat = table.concat

local function split_cmdline(cmdline)
    local args = {}
    local c = 1
    for arg in cmdline:gmatch("[^%z]+") do
        args[c] = arg
        c = c + 1
    end
    return concat(args, " ")
end

local cmdline = pywith("/proc/1089/cmdline")
print(split_cmdline(cmdline))