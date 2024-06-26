---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/1/2 10:45 PM
---

-- for markdown trans

require("eclass")
local pystring = require("pystring")

local class = class
local Clmd = class("lmd")
local error = error
local unpack = unpack
local ipairs = ipairs
local format = string.format
local sub = string.sub
local gsub = string.gsub
local find = string.find
local byte = string.byte
local insert = table.insert
local join = pystring.join
local split = pystring.split
local strip = pystring.strip
local startswith = pystring.startswith
local endswith = pystring.endswith
local srcPath = ""

function Clmd:_init_()
end

function Clmd:pTitle(s)
    local res = split(s, " ", 1)
    if #res < 2 then
        error(format("bad markdown: %s", s))
    end
    local head, value = unpack(res)
    local level = #head
    local tag = format("<h%d>", level)
    local etag = format("</h%d>", level)
    return join("", {tag, value, etag})
end

local function boldItalic(s)
    if sub(s, -4, -4) == "\\" then
        return s
    end
    return join("", {"<strong><em>", sub(s, 4, -4), "</em></strong>"})
end

local function bold(s)
    if sub(s, -3, -3) == "\\" then
        return s
    end
    return join("", {"<strong>", sub(s, 3, -3), "</strong>"})
end

local function italic(s)
    if sub(s, -2, -2) == "\\" then
        return s
    end
    return join("", {"<em>", sub(s, 2, -2), "</em>"})
end

local function delete(s)
    if sub(s, -3, -3) == "\\" then
        return s
    end
    return join("", {"<s>", sub(s, 3, -3), "</s>"})
end

local function code1(s)
    return join("", {"<code>", sub(s, 2, -2), "</code>"})
end

local function code2(s)
    return join("", {"<code>", sub(s, 3, -3), "</code>"})
end

local function pBI(s)
    return gsub(s, "[%*_][%*_][%*_]%S.-%S-[%*_][%*_][%*_]", function(ss) return boldItalic(ss) end)
end

local function pBold(s)
    return gsub(s, "[%*_][%*_]%S.-%S-[%*_][%*_]", function(ss) return bold(ss) end)
end

local function pItalic(s)
    return gsub(s, "[%*_]%S.-%S-[%*_]", function(ss) return italic(ss) end)
end

local function pDelete(s)
    return gsub(s, "~~%S.-%S~~", function(ss) return delete(ss) end)
end

local function pEnter(s)
    return gsub(s, "%s%s+$", "<br>")
end

local function pCode(s)
    if find(s, "``") then
        return gsub(s, "``.-``", function(ss) return code2(ss)  end)
    else
        if sub(s, -2, -2) == "\\" then
            return s
        end
        return gsub(s, "`.-`", function(ss) return code1(ss)  end)
    end
end

local function images(s)
    local name, link = unpack(split(s, "](", 1))
    name = sub(name, 3)  -- ![]()
    link = sub(link, 1, -2)

    if sub(name, -1, -1) == "\\" then
        return s
    end
    if sub(link, -1, -1) == "\\" then
        return s
    end
    local path = format("%s%s", srcPath, link)
    return format('<img src="%s" alt="%s"/>', path, name)
end

local function links(s)
    local name, link = unpack(split(s, "](", 1))
    name = sub(name, 2)  -- []()
    link = sub(link, 1, -2)
    if sub(name, -1, -1) == "\\" then
        return s
    end
    if sub(link, -1, -1) == "\\" then
        return s
    end
    return format('<a href="%s">%s</a>', link, name)
end

local function pImages(s)
    return gsub(s, "!%[.-%]%(.-%)", function(ss) return images(ss)  end)
end

local function pLink(s)
    return gsub(s, "%[.-%]%(.-%)", function(ss) return links(ss)  end)
end

local function Quotes(quotes, res)
    local len = #quotes
    local start = 1
    local level = 1
    for i = start, len do
        local levels, body = unpack(split(quotes[i], " ", 1))
        local v = #levels
        if v > level then
            while v > level do
                insert(res, "<blockquote>")
                level = level + 1
            end
        elseif v < level then
            while v < level do
                insert(res, "</blockquote>")
                level = level - 1
            end
        end
        local line = join("", {"<p>", body, "</p>"})
        insert(res, line)
    end
    while level > 1 do
        insert(res, "</blockquote>")
        level = level - 1
    end
end

local function pQuote(quotes, res)
    insert(res, "<blockquote>")
    Quotes(quotes, res)
    insert(res, "</blockquote>")
end

local function countBlankTab(s)
    local blank = 0
    local tab = 0
    for i = 1, #s do
        local ch = byte(s, i)
        if ch == 0x20 then   -- for blank
            blank = blank + 1
        elseif ch == 0x09 then   -- for tab
            tab = tab + 1
        end
    end
    return blank, tab
end

local function level4BT(s)
    local blank, tab =countBlankTab(s)
    return tab + blank / 4
end

function Clmd:ol(ols, res)
    local len = #ols
    local start = 1
    local level = 0

    for i = start, len do
        local levels, body = unpack(split(ols[i], ".", 1))
        local v = level4BT(levels)
        if v > level then
            while v > level do
                insert(res, "<ol>")
                level = level + 1
            end
        elseif v < level then
            while v < level do
                insert(res, "</ol>")
                level = level - 1
            end
        end
        local line = join("", {"<li>", self:seg(sub(body, 2)), "</li>"})
        insert(res, line)
    end

    while level > 0 do
        insert(res, "</ol>")
        level = level - 1
    end
end

function Clmd:pOl(ols, res)
    insert(res, "<ol>")
    self:ol(ols, res)
    insert(res, "</ol>")
end

local function splitUl(s)
    if startswith(s, " ") then
        local pos = find(s, "%S", 1)
        return sub(s, 1, pos + 1), sub(s, pos + 2)
    else
        return unpack(split(s, " ", 1))
    end
end

function Clmd:ul(uls, res)
    local len = #uls
    local start = 1
    local level = 0

    for i = start, len do
        local levels, body = splitUl(uls[i])
        local v = level4BT(levels)
        if v > level then
            while v > level do
                insert(res, "<ul>")
                level = level + 1
            end
        elseif v < level then
            while v < level do
                insert(res, "</ul>")
                level = level - 1
            end
        end
        local line = join("", {"<li>", self:seg(body), "</li>"})
        insert(res, line)
    end

    while level > 0 do
        insert(res, "</ul>")
        level = level - 1
    end
end

function Clmd:pUl(uls, res)
    insert(res, "<ul>")
    self:ul(uls, res)
    insert(res, "</ul>")
end

local function pCodeTab(codes, res)
    insert(res, "<pre><code>")
    for _, line in ipairs(codes) do
        insert(res, sub(line, 2))
    end
    insert(res, "</code></pre>")
end

local function pCodeBlank(codes, res)
    insert(res, "<pre><code>")
    for _, line in ipairs(codes) do
        insert(res, sub(line, 5))
    end
    insert(res, "</code></pre>")
end

local function pCodeFence(codes, res)
    insert(res, "<pre><code>")
    for _, line in ipairs(codes) do
        insert(res, line)
    end
    insert(res, "</code></pre>")
end

local function tableAligns(line)
    local aligns = split(line, "|")
    local res = {}
    for i=2, #aligns - 1 do
        local cell = strip(aligns[i])
        if startswith(cell, ":") then
            if endswith(cell, ":") then
                insert(res, "center")
            else
                insert(res, "left")
            end
        else
            if endswith(cell, ":") then
                insert(res, "right")
            else
                insert(res, "nil")
            end
        end
    end
    return res
end

function Clmd:pTable(codes, res)
    local len = #codes
    local start = 3

    if len < 3 then
        return
    end

    local aligns = tableAligns(codes[2])
    insert(res, '<table border="1">')

    local heads = split(codes[1], "|")
    insert(res, "<tr>")
    for j=2, #heads - 1 do
        local cell = strip(heads[j])
        cell = self:seg(cell)
        local line
        if aligns[j - 1] == nil or aligns[j - 1] == "nil" then
            line = join("", {"<th>", cell, "</th>"})
        else
            line = join("", {format('<th align="%s">', aligns[j - 1]),
                                            cell, "</th>"})
        end
        insert(res, line)
    end
    insert(res, "</tr>")

    for i = start, len do
        local cells = split(codes[i], "|")
        insert(res, "<tr>")
        for j=2, #heads - 1 do
            local cell = strip(cells[j])
            cell = self:seg(cell)
            local line
            if aligns[j - 1] == nil or aligns[j - 1] == "nil" then
                line = join("", {"<td>", cell, "</td>"})
            else
                line = join("", {format('<td align="%s">', aligns[j - 1]),
                                          cell, "</td>"})
            end
            insert(res, line)
        end
        insert(res, "</tr>")
    end
    insert(res, "</table>")
end

local function escape(s)
    return sub(s, 2)
end

local function pEscape(s)
    return gsub(s, "\\.", function(ss) return escape(ss)  end)
end

function Clmd:seg(s)
    s = pBI(s)
    s = pBold(s)
    s = pItalic(s)
    s = pDelete(s)
    s = pCode(s)
    s = pImages(s)
    s = pLink(s)
    return pEscape(s)
end

function Clmd:pSeg(s)
    s = self:seg(s)
    return join("", {"<p>", pEnter(s), "</p>"})
end

function Clmd:toHtml(md, path)
    local mds = split(md, '\n')
    local res = {}
    local len = #mds
    local stop = 0
    srcPath = path or ""

    for i = 1, len do
        local line = mds[i]

        if i < stop then   -- no continue in lua
            goto continue
        end

        if find(line, "#+%s") then
            insert(res, self:pTitle(line))
        elseif find(line, ">%s") then   -- for block quote
            local j = i + 1
            local quotes = {line}
            while j <= len and find(mds[j], ">+%s") do
                insert(quotes, mds[j])
                j = j + 1
            end
            pQuote(quotes, res)
            stop = j
        elseif find(line, "^%d%.%s") then
            local j = i + 1
            local ols = {line}
            while j <= len and find(mds[j], "[\t%s]*%d%.%s") do
                insert(ols, mds[j])
                j = j + 1
            end
            self:pOl(ols, res)
            stop = j
        elseif find(line, "^[%-%*%+]%s") then
            local j = i + 1
            local uls = {line}
            while j <= len and find(mds[j], "[\t%s]*[%-%*%+]%s") do
                insert(uls, mds[j])
                j = j + 1
            end
            self:pUl(uls, res)
            stop = j
        elseif find(line, "^\t") then
            local j = i + 1
            local codes = {line}
            while j <= len and find(mds[j], "^\t") do
                insert(codes, mds[j])
                j = j + 1
            end
            pCodeTab(codes, res)
            stop = j
        elseif find(line, "^%s%s%s%s") then
            local j = i + 1
            local codes = {line}
            while j <= len and find(mds[j], "^%s%s%s%s") do
                insert(codes, mds[j])
                j = j + 1
            end
            pCodeBlank(codes, res)
            stop = j
        elseif find(line, "^```") then
            local j = i + 1
            local codes = {}
            while j <= len and not find(mds[j], "^```") do
                insert(codes, mds[j])
                j = j + 1
            end
            pCodeFence(codes, res)
            stop = j + 1
        elseif find(line, "^|") then
            local j = i + 1
            local codes = {line}
            while j <= len and find(mds[j], "^|") do
                insert(codes, mds[j])
                j = j + 1
            end
            self:pTable(codes, res)
            stop = j
        elseif find(line, "^[%*%-_][%*%-_][%*%-_]") then
            insert(res, "<hr>")
        else
            if #line > 0 then
                insert(res, self:pSeg(line))
            else
                insert(res, line)
            end
        end

        ::continue::
    end
    return join("\n", res)
end

return Clmd
