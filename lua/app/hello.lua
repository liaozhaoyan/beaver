require("eclass")

local class = class

local format = string.format
local Chello = class("test")

local counter = 0

local function index(tReq)
    counter = counter + 1
    return {body = format("beaver %d say hello.", counter)}
end

function Chello:_init_(inst, conf)
    inst:get("/", index)
end

return Chello
