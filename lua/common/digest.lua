local cffi = require("beavercffi")

local c_type, c_api = cffi.type, cffi.api
local mt = {}

local c_new = c_type.new
local c_str = c_type.string
local c_md5 = c_api.md5_digest
local c_sha1 = c_api.sha1_digest
local c_sha256 = c_api.sha256_digest

local md5_len = 32 + 1
local sha1_len = 40 + 1
local sha256_len = 64 + 1

function mt.md5(s)
    local ret = c_new("char[?]", md5_len)
    c_md5(s, #s, ret)
    return c_str(ret)
end

function mt.sha1(s)
    local ret = c_new("char[?]", sha1_len)
    c_sha1(s, #s, ret)
    return c_str(ret)
end

function mt.sha256(s)
    local ret = c_new("char[?]", sha256_len)
    c_sha256(s, #s, ret)
    return c_str(ret)
end

return mt
