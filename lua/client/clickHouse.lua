local require = require
require("eclass")
local ChttpKeepPool = require("http.httpKeepPool")

local digest = require("common.digest")
local system = require("common.system")
local pystring = require("pystring")

local ipairs = ipairs
local format = string.format
local deepcopy = system.deepcopy
local b64_encode = digest.b64_encode
local url_encode = digest.url_encode
local split = pystring.split

local class = class
local CclickHouse = class("clickHouse", ChttpKeepPool)

function CclickHouse:_init_(url, db, user, pswd)
    local uri = format("/?database=%s", url_encode(db))
    self._url = url .. uri
    self._headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
    }
    if user and pswd then
        self._headers["Authorization"] = "Basic " .. b64_encode(user .. ":" .. pswd)
    end
    local conf = {
        host = url,
    }
    ChttpKeepPool._init_(self, conf, 4, 1000, 2)
end

local function parseRes(body)
    local rows = split(body, "\n")
    local tRes = {}
    for i, row in ipairs(rows) do
        if #row > 0 then
            local cols = split(row, "\t")
            if #cols > 0 then
                tRes[i] = {}
                for j, col in ipairs(cols) do
                    tRes[i][j] = col
                end
            end
        end
    end
    return tRes
end

function CclickHouse:execute(sql)
    local headers = deepcopy(self._headers)
    local reqs = {
            url = self._url,
            verb = "POST",
            headers = headers,
            body = sql,
        }
    local tRes, msg = self:req(reqs)
    if tRes then
        if tRes.code then
            if tRes.code == "200" then
                return true, parseRes(tRes.body)
            else
                return false, format("httpKeepPool:req code:%s, body: %s", tRes.code, tRes.body)
            end
        else
            return false, "httpKeepPool:req no res code."
        end
    else
        return false, "httpKeepPool:req failed, msg: " .. msg
    end
end

return CclickHouse
