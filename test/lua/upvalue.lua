local a = 1

local function upvalue(b)
    a = a + b
    return a
end

for i = 1, 100000000 do
    upvalue(i)
end
print("ok.")

-- use 0m0.123s