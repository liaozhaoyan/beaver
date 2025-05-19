local require = require
local pystring = require("pystring")
local find = pystring.find
local unpack = unpack
local lpeg = require("lpeg")
local P, R, S, C, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct

-- 模式定义
local digit = R('09')
local letter = R('az', 'AZ')
local allowed_punct = S("-._")
local scheme = ((C(letter^1) * P"://"))^-1
local uriScheme = ((C(letter^1) * P"://"))^1
local host = C((letter + digit + allowed_punct)^1)
local port = (P":" * C(digit^1))^-1
local path = P("/")^0
local uriPath = (C(P"/" * (letter + digit + S("-_~.!$&'()*+,;=:/?@#%[]{}"))^0))^0
local end_of_string = P(-1)

-- 完整的模式
local url_pattern_host = C((P("http://") + P("https://")) * (letter + digit + allowed_punct)^1 * (P":" * digit^1)^-1)
local url_pattern_host_uri = Ct(url_pattern_host * uriPath * end_of_string)
local url_pattern = Ct(scheme * host * port * path * end_of_string)
local url_path_pattern = Ct(uriScheme * host * port * uriPath)

local mt = {}

local sslScheme = {
    https = true
}

function mt.parse(url)
    local res = url_pattern:match(url)
    if res then
        local len = #res
        if len == 1 then
            return nil, res[1]
        elseif len == 2 then
            if find(url, "://") > 0 then  -- for scheme host http://host
                return res[1], res[2], nil
            else -- for host:port
                return nil, res[1], res[2]
            end
        else
            return res[1], res[2], res[3], res[4]
        end
    end
end

function mt.parsePath(url)
    local res = url_path_pattern:match(url)
    if res then
        local len = #res
        if len == 2 then -- only scheme host
            return res[1], res[2], sslScheme[res[1]] and "443" or "80", "/"
        elseif len == 3 then
            if res[3]:sub(1,1) == "/" then  -- has path, no port
                return res[1], res[2], sslScheme[res[1]] and "443" or "80", res[3]
            else
                return res[1], res[2], res[3], "/"
            end
        else  -- 4
            return unpack(res)
        end
    end
end

function mt.parseHostUri(url)
    local res = url_pattern_host_uri:match(url)
    if res then
        local len = #res
        if len == 1 then
            return res[1], "/"
        end
        return unpack(res)
    end
end

function mt.isSsl(sch)
    return sslScheme[sch]
end

return mt