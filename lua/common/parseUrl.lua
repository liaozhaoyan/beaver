local require = require
local pystring = require("pystring")
local find = pystring.find
local lpeg = require("lpeg")
local P, R, S, C = lpeg.P, lpeg.R, lpeg.S, lpeg.C

-- 模式定义
local digit = R('09')
local letter = R('az', 'AZ')
local allowed_punct = S("-.")
local scheme = ((C(letter^1) * P"://"))^-1
local host = C((letter + digit + allowed_punct)^1)
local port = (P":" * C(digit^1))^-1
local path = P("/")^0
local end_of_string = P(-1)

-- 完整的模式
local url_pattern = lpeg.Ct(scheme * host * port * path * end_of_string)

local mt = {}

function mt.parse(url)
    local res = url_pattern:match(url)
    if res then
        local len = #res
        if len == 1 then
            return nil, res[1], nil
        elseif len == 2 then
            if find(url, "://") > 0 then  -- for scheme host http://host
                return res[1], res[2], nil
            else -- for host:port
                return nil, res[1], res[2]
            end
        else
            return res[1], res[2], res[3]
        end
    end
end

local sslScheme = {
    https = true
}

function mt.isSsl(sch)
    return sslScheme[sch]
end

return mt