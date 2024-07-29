local require = require

local system = require("common.system")

local workVar = require("module.workVar")
local Credis = require("client.redis")
local workerGetVar = workVar.workerGetVar

local ipairs = ipairs
local pairs = pairs
local coReport = system.coReport
local create = coroutine.create
local resume = coroutine.resume
local msleep = workVar.msleep

local mt = {}

local function run()
    local beaver = workerGetVar().beaver
    local tReq = {
        beaver = beaver
    }
    while true do
        print("entry", os.time())
        local r = Credis.new(tReq, "127.0.0.1", 6379)
        msleep(1000)
        print("cli", os.time())
        r:close()
        msleep(1000)
        print("loop", os.time())
    end
end

function mt.start()
    local co = create(run)
    local ok, msg = resume(co)
    coReport(co, ok, msg)
end

return mt
