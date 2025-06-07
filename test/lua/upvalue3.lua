local function upvalue(b)
    local a = 1
    return b * 2 + a
end

for i = 1, 100000000 do
    upvalue(i)
end
print("ok.")
-- use 0m0.043s