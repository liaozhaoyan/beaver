# 从零基于beaver开发一个服务

## 基本概括
beaver 是一个基于 Lua 和 C 的异步 I/O 框架，旨在提供高性能的网络应用程序开发支持，beaver框架内提供了所需要的lua开发环境，自定义的api具体定义和用法可以参考文档。

## 开发者要求
1. 掌握http 基础；
2. 了解异步模型；
3. 掌握lua 编程；

## 简单介绍
基于beaver开发的服务基于异步请求post或get数据接口，对json数据进行处理、监控、转发等等一系列操作。根据bvapp仓库中的readme文档，搭建一个基础服务https://code.alibaba-inc.com/zhaoyan.lzy/bvapp 

## 功能概要
基础开发需要依赖于beaver/app路径下的文件。

### beaver/app/lua/app下存放基础核心功能代码。
以下代码在 hello 分支中：lua/app/hello.lua
require("eclass")  --引入构造类声明
local Chello = class("hello")  --类声明
local function index(tReq)   -- 回调函数
    return {body = string.format("hello guys!")}
end
function Chello:init(inst, conf)  -- 类构造函数
    inst:get("/", index)   -- 注册回调
end
return Chello  -- 返回类

### beaver/app/main下存放配置文件例如config.yaml文件。
main/config.yaml
worker:  # 标记工作线程
number: 1   # 工作线程数量
funcs:  # 功能列表
  ○ func: "httpServer"   # http server 服务
mode: "TCP"    # TCP 了类型
bind: "0.0.0.0"   # 绑定IP
port: 2000        # 绑定端口号
entry: "hello"  # 入口 函数 对应在 lua/app 目录下的文件

### 服务的启动统一为beaver/app/main下的run.sh文件，同时可以配置环境变量。

## 请求方式

### 服务可分为两种一是定时任务，二是http server服务，两者的config.yaml有所不同。
#### 定时任务可参考：
local require = require

local socket = require("socket")
local workVar = require("module.workVar")

local print = print
local gettime = socket.gettime
local create = coroutine.create
local yield = coroutine.yield
local resume = coroutine.resume
local status = coroutine.status
local msleep = workVar.msleep

local mt = {}

local timer

local function timerTest2()
    local i = 0
    while i < 10000 do
        local t1 =  gettime()
        msleep(2000)
        local t2 = gettime()
        assert(t2 - t1 >= 1.9 and t2 - t1 <= 2.1)
        i = i + 1
    end
    print("stop test2")
end

local function timerTest3()
    local i = 0
    while i < 10000 do
        local t1 = gettime()
        msleep(3000)
        local t2 = gettime()
        assert(t2 - t1 >= 2.9 and t2 - t1 <= 3.1)
        i = i + 1
    end
    print("stop test3")
end

function mt.call(beaver, args)
    print("run test.")
    local co = create(timerTest2)
    resume(co)
    co = create(timerTest3)
    resume(co)
end

return mt

#### config.yaml为
worker:
- number: 1
   entries:
   - entry: timeWork

#### http server服务可参考：
require("eclass")

local class = class

local format = string.format
local Chello = class("test")

local counter = 0

local function index(tReq)
    counter = counter + 1
    return {body = format("beaver %d say hello.", counter)}
end

function Chello:_init_(inst, conf)
    inst:get("/", index)
end

return Chello
##### config.yaml为
worker:
- func: "httpServer"
      mode: "TCP"
      bind: "0.0.0.0"
      port: 3385
      entry: test  # entry path

# 1、http request
http request 是一个常规的http 短连接客户端，如果需要使用长连接，需要掌握httpReq 的模块使用
## 1.1、依赖库
```lua
local request = require("http.request")
local http_get = request.get
```

## 1.2、get(url, header, body, tReq, tmo, proxy, maxLen)
```lua
local tRes, msg = http_get("http://www.baidu.com/")
if tRes then
    return tRes
else
    return {body = msg, code = 403}
end
```
参数说明：
* url: 完整请求路径，需要包含请求方法，不可省略 https:// 或 http:// 开头
* header： http 首部，可以为空
* body: http 内容，可以为空
* tReq: 关联请求table，在httpInst 场景需要传入
* tmo: 超时时间，可以为空
* proxy: 代理配置，可以为空
* maxLen: 最大接收缓冲区长度，可以为空

## 1.3、post(url, header, body, tReq, tmo, proxy, maxLen)
参考1.2

## 1.4、put(url, header, body, tReq, tmo, proxy, maxLen)
参考1.2

## 1.5、delete(url, header, body, tReq, tmo, proxy, maxLen)
参考1.2

# 2、 httpPool

httpPool 是http 连接池的实现，分为短连接池（ChttpPool）和长连接池(ChttpKeepPool)。

## 2.1、短连接池 （ChttpPool）

短连接池通常用于分散接入侧的连接压力，用于缓解后端服务并发压力，

### 2.1.1、构造函数

```lua
local ChttpPool = require("http.httpPool")
local pool = ChttpPool.new()
```
new 有3 个参数：
* maxConn 连接池最大并发连接数， 不配置默认为4
* maxPool 最大连接池连接数量，不配置默认为1000
* guardPeriod 巡检周期，不配置默认为2秒

### 2.1.2、req 请求函数 ChttpPool:req(reqs)
参数reqs 请求列表
```lua
    local reqs = {
        url = url,   -- 请求url 
        verb = "GET",  -- 方法 
        host = host,  -- 主机名 如果不配置，则从url 里面解析
        uri = uri,   -- uri 请求路径，如果不配置，则从url 里面解析
        headers = headers -- http 首部结构体 可以为空
        body = body  -- http 内容 可以为空
        tmo = tmo or 10,  -- 超时时间 可以为空
        proxy = proxy,  -- 代理配置  可以为空
        maxLen = maxLen or 2 * 1024 * 1024 -- 最大长度， 可以为空
    }
    return pool:req(reqs)
```

### 2.1.3、ChttpPool:get(url, tmo, proxy, maxLen)
参数参考2.1.2，只是加上了verb 方法。

### 2.1.4、ChttpPool:cancel()
停用连接池，后续连接请求将进不来

## 2.2、长连接池 （ChttpKeepPool）
长连接池通常用于与后端服务保持长连接，通常用于后端连接服务优化。

### 2.2.1、构造函数

```lua
local ChttpKeepPool = require("http.httpPool")
local pool = ChttpKeepPool.new(conf)
```
new 有4 个参数：
* conf 配置参数，成员参考后面描述
* maxConn 连接池最大并发连接数， 不配置默认为4
* maxPool 最大连接池连接数量，不配置默认为1000
* guardPeriod 巡检周期，不配置默认为2秒

conf 参数列表
* host：目标头，如 http://www.baidu.com
* keepMax： 长连接最长空闲保持时间
* tmo: 连接超时
* proxy： 代理参数
* maxLen: 最大接收缓冲区

### 2.2.2、req 请求函数 ChttpKeepPool:req(reqs)
```lua
    local reqs = {
            url = url,  -- url, 对应的host段必须和httpKeepPool保持一致
            verb = "GET",
            headers = headers,  -- 可以为空
            body = body  -- 可以为空
        }
    return self:req(reqs)
```

### 2.2.3、ChttpKeepPool:get(url, headers, body)
参考  2.2.2
### 2.2.4、ChttpKeepPool:post(url, headers, body)
参考  2.2.2
### 2.2.5、ChttpKeepPool:put(url, headers, body)
参考  2.2.2
### 2.2.6、ChttpKeepPool:delete(url, headers, body)
参考  2.2.2

### 2.2.7、ChttpKeepPool:cancel()
参考 2.1.4


