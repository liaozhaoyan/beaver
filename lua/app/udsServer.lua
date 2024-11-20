local require = require
require("eclass")

local system = require("common.system")
local CudsServer = class("CudsServer")
local concat = table.concat

function CudsServer:_init_(conf)
    print("udsServer init.")
    system.dumps(conf)
end

-- accept fd 回调，ctxt 为上下文数据，默认初始化为一个table
function CudsServer:accept(beaver, fd, ctxt)
    print("udsServer accept: ", fd)
    ctxt.buff = {}
    ctxt.len = 0
    ctxt.index = 1
    ctxt.total = 0
end

local function send_file(ctxt)
    local buff = concat(ctxt.buff)
    print("udsServer read: ", ctxt.len, #buff)
    ctxt.total = ctxt.total + ctxt.len
    ctxt.len = 0
    ctxt.index = 1
    ctxt.buff = {}
end

-- epoll 可读事件回调，ctxt 为上下文数据，
-- 读数据建议采用 beaver:read 方法, 如果不配置长度时，默认读取64k
-- 
function CudsServer:read(beaver, fd, ctxt)  -- should 
    local s = beaver:read(fd, 1024 * 1024)
    if s then
        ctxt.buff[ctxt.index] = s
        ctxt.index = ctxt.index + 1
        ctxt.len = ctxt.len + #s
        if ctxt.len >= 4 * 1024 * 1024 then
            send_file(ctxt)
        end
        return 0
    else
        return
    end
end

-- 关闭事件回调，无需close fd 和释放ctxt
function CudsServer:close(beaver, fd, ctxt)
    send_file(ctxt)
    print("udsServer close: ", fd, ctxt.total)
end

return CudsServer