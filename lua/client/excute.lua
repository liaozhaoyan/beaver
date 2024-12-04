local require = require
local yield = coroutine.yield
local resume = coroutine.resume
local running = coroutine.running
local insert = table.insert
local lpeg = require("lpeg")
local Cpopen = require("client.popen")
local workVar = require("module.workVar")

local P, S, C, Ct = lpeg.P, lpeg.S, lpeg.C, lpeg.Ct

local beaver = workVar.workerGetVar().beaver

local mt = {}

local space = S(' \t')^1
local quote = P('"')
local single_quote = P("'")
local escape = P('\\')
local anything = P(1)

local quoted_str = quote * (
    (escape * anything + (anything - quote))^0
) * quote

local single_quoted_str = single_quote * (
    (escape * anything + (anything - single_quote))^0
) * single_quote

local plain_word = (anything - space)^1

local command_pattern = C(quoted_str) +
                        C(single_quoted_str) +
                        C(plain_word)

local command_line_pattern = (command_pattern * (space^0 * command_pattern)^0)^1

-- 'echo "Hello, World!" \\"escaped quotes\\" and signal \'test\''

function mt.parse_command_line(command_line)
    local cmds, c = {}, 1
    local start = 1  -- 初始化起始匹配位置
    while start <= #command_line do
        local match = command_line_pattern:match(command_line, start)
        if match then
            cmds[c] = match
            c = c + 1
            -- 更新起始匹配位置
            start = start + #match
            -- 跳过空格
            while start <= #command_line and space:match(command_line:sub(start, start)) do
                start = start + 1
            end
        else
            break  -- 如果没有匹配，退出循环
        end
    end
    return cmds
end

function mt.execute(cmd)
    local cmds = mt.parse_command_line(cmd)
    local co = running()
    local p
    local function cb(fd)
        beaver:read(fd)
        return 0
    end
    local function cbEvent(fd, event)
        if event == 1 then
            local rets = p:wait()
            resume(co, rets[1][3])  --wake up execut
        end
        return 0
    end

    p = Cpopen.new(beaver, cmds, cb, cbEvent)
    local code = yield()
    if code ~= 0 then
        print("execute ", cmd, "failed, code:", code)
    end
    return code
end

return mt
