---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2024/1/18 4:44 PM
---

require("eclass")

local Ctest = class("test")

local counter = 0

local function index(tReq)
    counter = counter + 1
    return {body = string.format("beaver %d say hello.", counter)}
end

function Ctest:_init_(inst, conf)
    inst:get("/", index)
end

return Ctest