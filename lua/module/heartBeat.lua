local require = require
local system = require("common.system")

local create = coroutine.create
local resume = coroutine.resume
local coReport = system.coReport
local format = string.format

local mt = {}

local seq = 1000

local function run(sleep, thread)
    while true do
        local res = sleep(seq)
        if res ~= seq then
            break
        end
    end
    print(format("heart beat thread %s is offline", thread))
end

function mt.start(sleep, thread)
    local co = create(run)
    local res, msg = resume(co, sleep, thread)
    coReport(co, res, msg)
end

return mt