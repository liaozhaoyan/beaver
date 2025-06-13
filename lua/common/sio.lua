local require = require

local cffi = require("beavercffi")
local ffi = require("ffi")
local pstat = require("posix.sys.stat")
local unistd = require("posix.unistd")
local stdio = require("posix.stdio")
local zlib = require("zlib")
local struct = require("struct")

local c_type, c_api = cffi.type, cffi.api

local c_new = ffi.new
local c_writev = c_api.b_writev
local stat = pstat.stat
local char = string.char
local concat = table.concat
local floor = math.floor
local access = unistd.access
local rename = stdio.rename
local deflate = zlib.deflate
local crc32 = zlib.crc32
local pack = struct.pack
local os_time = os.time

local m = {}

--- bulk writev
--- --
--- @param fd number, file descriptor
--- @param vec table, string list table
--- @return number write length.
function m.writes(fd, vec)
    local len = #vec
    if len == 0 then
        return 0
    end
    local write_len = 0
    local iov = c_new("struct iovec[?]", len)
    for i = 1, len do
        local s_vec = #vec[i]
        if s_vec > 0 then
            iov[write_len].iov_base = vec[i]
            iov[write_len].iov_len = s_vec
            write_len = write_len + 1
        end
    end
    return c_writev(fd, iov, write_len)
end

local function binary_search(poss, offset)
    local len = #poss
    local left, right = 1, len
    while left <= right do
        local mid = floor((left + right) / 2)
        local v = poss[mid]
        if v == offset then
            return mid, offset
        elseif v < offset then
            left = mid + 1
        else
            right = mid - 1
        end
    end
    return left - 1, poss[left -1]
end

--- bulk writev for async.
--- @param fd number, file descriptor
--- @param vec table, string list table
--- @return number total
--- @return function|nil function(number); 
function m.awrites(fd, vec)
    local len = #vec
    if len == 0 then
        return 0, nil
    end

    local size, write_len = 0, 0
    local poss = {0}
    local iov = c_new("struct iovec[?]", len)
    for i = 1, len do
        local s_vec = #vec[i]
        if s_vec > 0 then
            size = size + s_vec
            poss[write_len + 2] = size
            iov[write_len].iov_base = vec[i]
            iov[write_len].iov_len = s_vec
            write_len = write_len + 1
        end
    end
    if size == 0 then
        return 0, nil
    end
    return size, function (offset)
        if offset == 0 then
            return c_writev(fd, iov, write_len)
        else
            local index, pos = binary_search(poss, offset)

            local w_iov = iov[index - 1]
            local diff = offset - pos
            if diff > 0 then
                local r_base, r_len = w_iov.iov_base, w_iov.iov_len
                w_iov.iov_base = w_iov.iov_base + diff
                w_iov.iov_len = w_iov.iov_len - diff
                local ret = c_writev(fd, w_iov, write_len - index + 1)
                w_iov.iov_base, w_iov.iov_len = r_base, r_len
                return ret
            else
                return c_writev(fd, w_iov, write_len - index + 1)
            end
        end
    end
end

--- get file size
--- @param path string, file path
--- @return number file size, if file not exist, return -1
function m.fileSize(path)
    local res = stat(path)
        if res then
            return res.st_size
        end
    return -1
end

-- check file exist.
--- @param path string, file path
--- @return boolean file exist or not
function m.exist(path)
    return access(path) == 0
end

-- rename file
--- @param old string, old file path
--- @param new string, new file path
--- @return boolean rename success or not
function m.rename(old, new)
    return(rename(old, new) == 0)
end

-- gizp data
--- @param data string, data
--- @param path string, file path
--- @return table stream table
function m.gizps(data, path)
    local compressor = deflate(5,15)
    local gzip_data = {}
    gzip_data[1] = char(0x1F, 0x8B, 0x08, 0x08) -- magic number,  compression method, flags, has file name
    gzip_data[2] = pack("<I4", os_time() % (2^32)) -- modification time
    gzip_data[3] = char(0x02, 0x03) -- extra flags, OS type
    gzip_data[4] = path  -- extension file name.
    gzip_data[5] = char(0x00) -- end
    local cSize = #data
    local crc = 0
    crc = crc32(crc, data)
    gzip_data[6] = compressor(data, "finish"):sub(3):sub(1, -5)  -- strip head 2 bytes and  end 4 bytes
    gzip_data[7] = pack("<I4<I4", crc, cSize)   -- crc and original size
    return gzip_data
end

-- gizp data
--- @param data string, data
--- @param path string, file path
--- @return string gizp data
function m.gizp(data, path)
    return concat(m.gizps(data, path))
end

return m
