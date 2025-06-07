local s = "abc\0def"
print(#s)

-- 方法 1：使用 string.char(0)
local s = "abc" .. string.char(0) .. "def"
print(#s)  -- 输出 7（正确，字符串包含空字符）

-- 方法 2：使用转义字符 \000（Lua 支持的空字符表示）
local s = "abc\000def"
print(#s)  -- 输出 7（正确，字符串包含空字符）