local require = require
local system = require("common.system")
local cffi = require("beavercffi")

local c_type, c_api = cffi.type, cffi.api
local mt = {}

local error = error
local format = string.format
local byte = string.byte
local concat = table.concat
local floor = math.floor
local c_new = c_type.new
local c_str = c_type.string
local c_md5 = c_api.md5_digest
local c_sha1 = c_api.sha1_digest
local c_sha224 = c_api.sha224_digest
local c_sha256 = c_api.sha256_digest
local c_sha384 = c_api.sha384_digest
local c_sha512 = c_api.sha512_digest
local c_hmac = c_api.hmac_digest
local c_b64_encode = c_api.base64_encode
local c_b64_decode = c_api.base64_decode
local c_hex_encode = c_api.hex_encode

local md5_len = 32 + 1
local sha1_len = 40 + 1
local sha224_len = 56 + 1
local sha256_len = 64 + 1
local sha384_len = 96 + 1
local sha512_len = 128 + 1

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

function mt.sha224(s)
    local ret = c_new("char[?]", sha224_len)
    c_sha224(s, #s, ret)
    return c_str(ret)
end

function mt.sha256(s)
    local ret = c_new("char[?]", sha256_len)
    c_sha256(s, #s, ret)
    return c_str(ret)
end

function mt.sha384(s)
    local ret = c_new("char[?]", sha384_len)
    c_sha384(s, #s, ret)
    return c_str(ret)
end

function mt.sha512(s)
    local ret = c_new("char[?]", sha512_len)
    c_sha512(s, #s, ret)
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
    local res = c_str(digest, len)
    return res
end

function mt.hex_encode(s)
    local len = #s
    local rlen = len * 2 + 1
    local digest = c_new("char[?]", rlen)
    c_hex_encode(s, len, digest)
    return c_str(digest)
end

function mt.b64_encode(s)
    local len = #s
    local rlen = floor((len + 2) / 3 * 4)
    local digest = c_new("char[?]", rlen)
    local ret = c_b64_encode(s, len, digest)

    if ret < 0 then
        error("b64_encode failed")
    end
    return c_str(digest, ret)
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

local urlIgnore = {
    [' '] = '+',
    ['-'] = '-',
    ['_'] = '_',
    ['~'] = '~',
    ['.'] = '.',
}
local function char_to_hex(byte_c)
    return format("%%%02X", byte_c)
end
-- refer to https://datatracker.ietf.org/doc/html/rfc3986
function mt.url_encode(url)
    local encoded = {}

    for i = 1, #url do
        local c = url:sub(i, i)
        local byte_c = byte(c)

        if byte_c >= 0x80 then  -- for non-ascii
            encoded[i] = char_to_hex(byte_c)
        else  -- for ascii
            if urlIgnore[c] then  -- for special chars
                encoded[i] = urlIgnore[c]
            elseif c:match("%w") then  -- for normal chars
                encoded[i] = c
            else   -- for other chars
                encoded[i] = char_to_hex(byte_c)
            end
        end
    end
    return concat(encoded)
end

return mt
