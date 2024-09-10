package.path = package.path .. ";../../lua/?.lua"

local dnsmatch = require("common.dnsmatch")

local isdns = dnsmatch.isdns

assert(isdns("baidu") == true)
assert(isdns("bai*du") == false)
assert(isdns("BAIDU") == true)
assert(isdns("bai-du") == true)
assert(isdns("bai-du-") == true)

assert(isdns("baidu.") == false)
assert(isdns(".baidu") == false)

assert(isdns("baidu.com") == true)
assert(isdns("bai-du.com") == true)
assert(isdns("www.baidu.com") == true)
assert(isdns("www.baidu.com.") == false)
assert(isdns(".www.baidu.com") == false)

print("ok.")
