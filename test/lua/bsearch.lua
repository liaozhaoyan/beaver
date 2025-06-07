local floor = math.floor

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


local poss={0, 3, 5, 8, 10, 12}

print(binary_search(poss, 2))
print(binary_search(poss, 3))
print(binary_search(poss, 11))
print(binary_search(poss, 14))

poss={3}
print(binary_search(poss, 3))
print(binary_search(poss, 11))
print(binary_search(poss, 14))

poss={3, 12}
print(binary_search(poss, 3))
print(binary_search(poss, 11))
print(binary_search(poss, 14))
