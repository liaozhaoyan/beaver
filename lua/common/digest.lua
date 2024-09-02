local cffi = require("beavercffi")

local c_type, c_api = cffi.type, cffi.api
local mt = {}

local error = error
local c_new = c_type.new
local c_str = c_type.string
local c_md5 = c_api.md5_digest
local c_sha1 = c_api.sha1_digest
local c_sha256 = c_api.sha256_digest
local c_hmac = c_api.hmac
local c_b64_encode = c_api.b64_encode
local c_b64_decode = c_api.b64_decode

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

local algo_map = {  -- refer to native/digest.c
    md5 = 0,
    sha1 = 1,
    sha224 = 2,
    sha256 = 3,
    sha384 = 4,
    sha512 = 5,
}
function mt.hmac(key, data, algo)
    local algo_mode = algo_map[algo]
    if not algo_mode then
        error("invalid algo: " .. algo)
    end

    local digest = c_new("char[?]", 128)
    local len = c_hmac(key, #key, data, #data, digest, algo_mode)
    if len < 0 then
        error("hmac failed")
    end
    local res = c_str(digest)
    return res:sub(1, len)
end

function mt.b64_encode(s)
    local len = #s
    local digest = c_new("char[?]", (len + 2) / 3 * 4)
    local ret = c_b64_encode(s, len, digest)

    if ret < 0 then
        error("b64_encode failed")
    end
    return c_str(digest, len)
end

function mt.b64_decode(s)
    local len = #s
    local digest = c_new("char[?]", len)
    local ret = c_b64_decode(s, len, digest)
    if ret < 0 then
        error("b64_decode failed")
    end
    return c_str(digest, ret)
end

return mt
