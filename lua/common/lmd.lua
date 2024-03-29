---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/1/2 10:45 PM
---

-- for markdown trans

require("eclass")
local pystring = require("pystring")

local Clmd = class("lmd")
local srcPath = ""

function Clmd:_init_()
    self._escs = '\\`*_{}[]()>#+-.!'
    self._cStr = "#+->_`|"
    self._cbs = {
        ["#"] = function(s)  return self:pTitle(s) end,
    }
end

function Clmd:pTitle(s)
    local res = pystring.split(s, " ", 1)
    if #res < 2 then
        error("bad markdown: "..s)
    end
    local head, value = unpack(res)
    local level = #head
    local tag = string.format("<h%d>", level)
    local etag = string.format("</h%d>", level)
    return pystring.join("", {tag, value, etag})
end

local function boldItalic(s)
    if string.sub(s, -4, -4) == "\\" then
        return s
    end
    return pystring.join("", {"<strong><em>", string.sub(s, 4, -4), "</em></strong>"})
end

local function bold(s)
    if string.sub(s, -3, -3) == "\\" then
        return s
    end
    return pystring.join("", {"<strong>", string.sub(s, 3, -3), "</strong>"})
end

local function italic(s)
    if string.sub(s, -2, -2) == "\\" then
        return s
    end
    return pystring.join("", {"<em>", string.sub(s, 2, -2), "</em>"})
end

local function delete(s)
    if string.sub(s, -3, -3) == "\\" then
        return s
    end
    return pystring.join("", {"<s>", string.sub(s, 3, -3), "</s>"})
end

local function code1(s)
    return pystring.join("", {"<code>", string.sub(s, 2, -2), "</code>"})
end

local function code2(s)
    return pystring.join("", {"<code>", string.sub(s, 3, -3), "</code>"})
end

local function pBI(s)
    return string.gsub(s, "[%*_][%*_][%*_]%S.-%S-[%*_][%*_][%*_]", function(s) return boldItalic(s) end)
end

local function pBold(s)
    return string.gsub(s, "[%*_][%*_]%S.-%S-[%*_][%*_]", function(s) return bold(s) end)
end

local function pItalic(s)
    return string.gsub(s, "[%*_]%S.-%S-[%*_]", function(s) return italic(s) end)
end

local function pDelete(s)
    return string.gsub(s, "~~%S.-%S~~", function(s) return delete(s) end)
end

local function pEnter(s)
    return string.gsub(s, "%s%s+$", "<br>")
end

local function pCode(s)
    if string.find(s, "``") then
        return string.gsub(s, "``.-``", function(s) return code2(s)  end)
    else
        if string.sub(s, -2, -2) == "\\" then
            return s
        end
        return string.gsub(s, "`.-`", function(s) return code1(s)  end)
    end
end

local function images(s)
    local name, link = unpack(pystring.split(s, "](", 1))
    name = string.sub(name, 3)  -- ![]()
    link = string.sub(link, 1, -2)

    if string.sub(name, -1, -1) == "\\" then
        return s
    end
    if string.sub(link, -1, -1) == "\\" then
        return s
    end
    local path = srcPath .. link
    return string.format('<img src="%s" alt="%s"/>', path, name)
end

local function links(s)
    local name, link = unpack(pystring.split(s, "](", 1))
    name = string.sub(name, 2)  -- []()
    link = string.sub(link, 1, -2)
    if string.sub(name, -1, -1) == "\\" then
        return s
    end
    if string.sub(link, -1, -1) == "\\" then
        return s
    end
    return string.format('<a href="%s">%s</a>', link, name)
end

local function pImages(s)
    return string.gsub(s, "!%[.-%]%(.-%)", function(s) return images(s)  end)
end

local function pLink(s)
    return string.gsub(s, "%[.-%]%(.-%)", function(s) return links(s)  end)
end

local function Quotes(quotes, res)
    local len = #quotes
    local start = 1
    local level = 1
    for i = start, len do
        local levels, body = unpack(pystring.split(quotes[i], " ", 1))
        local v = #levels
        if v > level then
            while v > level do
                table.insert(res, "<blockquote>")
                level = level + 1
            end
        elseif v < level then
            while v < level do
                table.insert(res, "</blockquote>")
                level = level - 1
            end
        end
        local line = pystring.join("", {"<p>", body, "</p>"})
        table.insert(res, line)
    end
    while level > 1 do
        table.insert(res, "</blockquote>")
        level = level - 1
    end
end

local function pQuote(quotes, res)
    table.insert(res, "<blockquote>")
    Quotes(quotes, res)
    table.insert(res, "</blockquote>")
end

local function countBlankTab(s)
    local blank = 0
    local tab = 0
    for i = 1, #s do
        local ch = string.byte(s, i)
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
        local levels, body = unpack(pystring.split(ols[i], ".", 1))
        local v = level4BT(levels)
        if v > level then
            while v > level do
                table.insert(res, "<ol>")
                level = level + 1
            end
        elseif v < level then
            while v < level do
                table.insert(res, "</ol>")
                level = level - 1
            end
        end
        local line = pystring.join("", {"<li>", self:seg(string.sub(body, 2)), "</li>"})
        table.insert(res, line)
    end

    while level > 0 do
        table.insert(res, "</ol>")
        level = level - 1
    end
end

function Clmd:pOl(ols, res)
    table.insert(res, "<ol>")
    self:ol(ols, res)
    table.insert(res, "</ol>")
end

local function splitUl(s)
    if pystring.startswith(s, " ") then
        local pos = string.find(s, "%S", 1)
        return string.sub(s, 1, pos + 1), string.sub(s, pos + 2)
    else
        return unpack(pystring.split(s, " ", 1))
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
                table.insert(res, "<ul>")
                level = level + 1
            end
        elseif v < level then
            while v < level do
                table.insert(res, "</ul>")
                level = level - 1
            end
        end
        local line = pystring.join("", {"<li>", self:seg(body), "</li>"})
        table.insert(res, line)
    end

    while level > 0 do
        table.insert(res, "</ul>")
        level = level - 1
    end
end

function Clmd:pUl(uls, res)
    table.insert(res, "<ul>")
    self:ul(uls, res)
    table.insert(res, "</ul>")
end

local function pCodeTab(codes, res)
    table.insert(res, "<pre><code>")
    for _, line in ipairs(codes) do
        table.insert(res, string.sub(line, 2))
    end
    table.insert(res, "</code></pre>")
end

local function pCodeBlank(codes, res)
    table.insert(res, "<pre><code>")
    for _, line in ipairs(codes) do
        table.insert(res, string.sub(line, 5))
    end
    table.insert(res, "</code></pre>")
end

local function pCodeFence(codes, res)
    table.insert(res, "<pre><code>")
    for _, line in ipairs(codes) do
        table.insert(res, line)
    end
    table.insert(res, "</code></pre>")
end

local function tableAligns(line)
    local aligns = pystring.split(line, "|")
    local res = {}
    for i=2, #aligns - 1 do
        local cell = pystring.strip(aligns[i])
        if pystring.startswith(cell, ":") then
            if pystring.endswith(cell, ":") then
                table.insert(res, "center")
            else
                table.insert(res, "left")
            end
        else
            if pystring.endswith(cell, ":") then
                table.insert(res, "right")
            else
                table.insert(res, "nil")
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
    table.insert(res, '<table border="1">')

    local heads = pystring.split(codes[1], "|")
    table.insert(res, "<tr>")
    for j=2, #heads - 1 do
        local cell = pystring.strip(heads[j])
        cell = self:seg(cell)
        local line
        if aligns[j - 1] == nil or aligns[j - 1] == "nil" then
            line = pystring.join("", {"<th>", cell, "</th>"})
        else
            line = pystring.join("", {string.format('<th align="%s">', aligns[j - 1]),
                                            cell, "</th>"})
        end
        table.insert(res, line)
    end
    table.insert(res, "</tr>")

    for i = start, len do
        local cells = pystring.split(codes[i], "|")
        table.insert(res, "<tr>")
        for j=2, #heads - 1 do
            local cell = pystring.strip(cells[j])
            cell = self:seg(cell)
            local line
            if aligns[j - 1] == nil or aligns[j - 1] == "nil" then
                line = pystring.join("", {"<td>", cell, "</td>"})
            else
                line = pystring.join("", {string.format('<td align="%s">', aligns[j - 1]),
                                          cell, "</td>"})
            end
            table.insert(res, line)
        end
        table.insert(res, "</tr>")
    end
    table.insert(res, "</table>")
end

local function escape(s)
    return string.sub(s, 2)
end

local function pEscape(s)
    return string.gsub(s, "\\.", function(s) return escape(s)  end)
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
    return pystring.join("", {"<p>", pEnter(s), "</p>"})
end

function Clmd:toHtml(md, path)
    local mds = pystring.split(md, '\n')
    local res = {}
    local len = #mds
    local stop = 0
    srcPath = path or ""

    for i = 1, len do
        local line = mds[i]

        if i < stop then   -- no continue in lua
            goto continue
        end

        if string.find(line, "#+%s") then
            table.insert(res, self:pTitle(line))
        elseif string.find(line, ">%s") then   -- for block quote
            local j = i + 1
            local quotes = {line}
            while j <= len and string.find(mds[j], ">+%s") do
                table.insert(quotes, mds[j])
                j = j + 1
            end
            pQuote(quotes, res)
            stop = j
        elseif string.find(line, "^%d%.%s") then
            local j = i + 1
            local ols = {line}
            while j <= len and string.find(mds[j], "[\t%s]*%d%.%s") do
                table.insert(ols, mds[j])
                j = j + 1
            end
            self:pOl(ols, res)
            stop = j
        elseif string.find(line, "^[%-%*%+]%s") then
            local j = i + 1
            local uls = {line}
            while j <= len and string.find(mds[j], "[\t%s]*[%-%*%+]%s") do
                table.insert(uls, mds[j])
                j = j + 1
            end
            self:pUl(uls, res)
            stop = j
        elseif string.find(line, "^\t") then
            local j = i + 1
            local codes = {line}
            while j <= len and string.find(mds[j], "^\t") do
                table.insert(codes, mds[j])
                j = j + 1
            end
            pCodeTab(codes, res)
            stop = j
        elseif string.find(line, "^%s%s%s%s") then
            local j = i + 1
            local codes = {line}
            while j <= len and string.find(mds[j], "^%s%s%s%s") do
                table.insert(codes, mds[j])
                j = j + 1
            end
            pCodeBlank(codes, res)
            stop = j
        elseif string.find(line, "^```") then
            local j = i + 1
            local codes = {}
            while j <= len and not string.find(mds[j], "^```") do
                table.insert(codes, mds[j])
                j = j + 1
            end
            pCodeFence(codes, res)
            stop = j + 1
        elseif string.find(line, "^|") then
            local j = i + 1
            local codes = {line}
            while j <= len and string.find(mds[j], "^|") do
                table.insert(codes, mds[j])
                j = j + 1
            end
            self:pTable(codes, res)
            stop = j
        elseif string.find(line, "^[%*%-_][%*%-_][%*%-_]") then
            table.insert(res, "<hr>")
        else
            if #line > 0 then
                table.insert(res, self:pSeg(line))
            else
                table.insert(res, line)
            end
        end

        ::continue::
    end
    return pystring.join("\n", res)
end

return Clmd
