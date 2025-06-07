
local function upvalue()
    local a = 1
    return function (b)
        a = a + b
        return a
    end
end

local func = upvalue()
for i = 1, 100000000 do
    func(i)
end
print("ok.")
-- use real	0m0.124s


