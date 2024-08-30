package.path = package.path .. ";../../lua/?.lua"

local parseUrl = require("common.parseUrl")
local parse = parseUrl.parse
local isSsl = parseUrl.isSsl

local url
local scheme, host, port

url = "172.16.0.12"
scheme, host, port = parse(url)
assert(scheme == nil)
assert(host == "172.16.0.12")
assert(port == nil)

url = "http://172.16.0.12"
scheme, host, port = parse(url)
assert(scheme == "http", scheme)
assert(host == "172.16.0.12")
assert(port == nil)

url = "http://172.16.0.12:8080"
scheme, host, port = parse(url)
assert(scheme == "http")
assert(host == "172.16.0.12")
assert(port == "8080")

url = "172.16.0.12:8080"
scheme, host, port = parse(url)
assert(scheme == nil, scheme)
assert(host == "172.16.0.12")
assert(port == "8080")

url = "http://172.16.0.12:8080/path"
scheme, host, port = parse(url)
assert(scheme == nil)
assert(host == nil)
assert(port == nil)

url = "www.baidu.com"
scheme, host, port = parse(url)
assert(scheme == nil)
assert(host == "www.baidu.com")
assert(port == nil)

url = "http://www.baidu.com"
scheme, host, port = parse(url)
assert(scheme == "http")
assert(host == "www.baidu.com")
assert(port == nil)

url = "http://www.baidu.com:8080"
scheme, host, port = parse(url)
assert(scheme == "http")
assert(host == "www.baidu.com")
assert(port == "8080")

url = "www.baidu.com:443"
scheme, host, port = parse(url)
assert(scheme == nil)
assert(host == "www.baidu.com")
assert(port == "443")

url = "www.baidu.com:443/path"
scheme, host, port = parse(url)
assert(scheme == nil)
assert(host == nil)
assert(port == nil)

url = "http://sysom-llm-service-sysom-pre:80"
scheme, host, port = parse(url)
assert(scheme == "http")
assert(host == "sysom-llm-service-sysom-pre")
assert(port == "80")

assert(isSsl("https") == true)
assert(not isSsl("http"))

print("testUrlParse success")
