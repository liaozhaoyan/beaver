local require = require
require("eclass")

local system = require("common.system")
local CudsServer = class("CudsServer")

function CudsServer:_init_(conf)
    print("udsServer init.")
    system.dumps(conf)
    self.ctxt = {}
end

function CudsServer:accept(beaver, fd)
    print("udsServer accept: ", fd)
    self.ctxt[fd] = 0
end

function CudsServer:read(beaver, fd)  -- should 
    local s = beaver:read(fd)
    if s then
        self.ctxt[fd] = self.ctxt[fd] + #s
        return s
    else
        return
    end
end

function CudsServer:close(beaver, fd)
    print("udsServer close: ", fd, "read: ", self.ctxt[fd])
    self.ctxt[fd] = nil
end

return CudsServer