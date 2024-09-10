local require = require
local lpeg = require("lpeg")
local P, R = lpeg.P, lpeg.R

local mt = {}
local dnscell = R("az", "AZ", "09")^1 * (P("-") * R("az", "AZ", "09")^0)^0
local dnspatten = dnscell * (P(".") * dnscell)^0 * -1

function mt.isdns(domain)
    if not domain or #domain == 0 then
        return false
    end
    return dnspatten:match(domain) ~= nil
end

return mt