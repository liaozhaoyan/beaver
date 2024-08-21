require("eclass")
local lpeg = require("lpeg")
local P, R, C, Ct = lpeg.P, lpeg.R, lpeg.C, lpeg.Ct

local slash = P("/")
local sVar = P(":")
local mVar = P("*")
local notSlash = R("az", "AZ", "09") + P("-") + P("_") + P(".")

local segMatch = C((sVar + mVar)^-1 * notSlash^1)
local capMatch = Ct((slash * segMatch)^0) * -1
local segPath = C(notSlash^1)
local capPath = Ct((slash * segPath)^0) * -1

local class = class
local type = type
local assert = assert
local concat = table.concat

local Ctrie = class("Trie")

function Ctrie:_init_()
    self._direct = {}
    self._trie = {}
end

local function setDirect(direct, path, cb)
    if direct[path] then
        return false, "aleady exist."
    else
        direct[path] = cb
        return true
    end
end

local function setNextTrie(nextTrie, seg)
    if nextTrie[seg] then
        return nextTrie[seg]
    else
        nextTrie[seg] = {}
        return nextTrie[seg]
    end
end

local function setTrieCb(trie, seg, vars, cb)
    if trie[seg] then
        return false, "trie aleady exist."
    else
        trie[seg] = {vars, cb}
        return true
    end
end

local function setTrie(trie, caps, cb)
    local len = #caps
    local nextTrie = trie
    local c, vars = 1, {}
    local cap, ch
    for i = 1, len - 1 do
        cap = caps[i]
        ch = cap:sub(1, 1)
        if ch == ":" then
            nextTrie = setNextTrie(nextTrie, ":")
            vars[c] = cap:sub(2)
            c = c + 1
        elseif ch == "*" then
            return false, "invalid path, * should at the end."
        else
            nextTrie = setNextTrie(nextTrie, cap)
        end
    end

    cap = caps[len]
    ch = cap:sub(1, 1)
    if ch == "*" then
        vars[c] = cap:sub(2)
        return setTrieCb(nextTrie, "*", vars, cb)
    elseif ch == ":" then
        vars[c] = cap:sub(2)
        return setTrieCb(nextTrie, ":", vars, cb)
    else
        return setTrieCb(nextTrie, cap, vars, cb)
    end
end

function Ctrie:add(path, cb)
    local direct = self._direct
    local trie = self._trie
    if path == "/" then
        return setDirect(direct, path, cb)
    else
        local caps = capMatch:match(path)
        if not caps or #caps == 0 then
            return false, "invalid path. type: " .. type(caps)
        end

        if path:match("[%*:]") then  -- trie tree
            return setTrie(trie, caps, cb)
        else
            return setDirect(direct, path, cb)
        end
    end
end

local function packVars(keys, values)
    assert(#keys == #values, "keys and values not match, may some logic bug.")
    local res = {}
    for i = 1, #keys do
        res[keys[i]] = values[i]
    end
    return res
end

local function matchTrie(trieNext, caps, capIndex, vars, varIndex)
    if trieNext["*"] then  -- for *
        local res = trieNext["*"]
        local value = concat(caps, "/", capIndex)
        vars[varIndex] = value
        return res[2], packVars(res[1], vars)
    end

    local cap = caps[capIndex]
    local getTrie = trieNext[cap]
    if getTrie then  -- for direct node at first
        local res, rVars = matchTrie(getTrie, caps, capIndex + 1, vars, varIndex)
        if res then
            return res, rVars
        end
    end

    if trieNext[":"] then
        local res = trieNext[":"]
        vars[varIndex] = cap
        local r, rVars = matchTrie(res, caps, capIndex + 1, vars, varIndex + 1)
        if r then
            return r, rVars
        end
    end

    if trieNext[2] and capIndex == #caps + 1 then
        -- for result node, should be the last, so capIndex == #caps + 1
        return trieNext[2], packVars(trieNext[1], vars)
    end
end

function Ctrie:match(path)
    local direct = self._direct
    if path == "" or path == "/" then
        return direct["/"]
    end
    if direct[path] then
        return direct[path]
    end

    local caps = capPath:match(path)
    if not caps then
        return false, "invalid url path."
    end
    local vars = {}
    local cb, mVars = matchTrie(self._trie, caps, 1, vars, 1)
    return cb, mVars
end

return Ctrie