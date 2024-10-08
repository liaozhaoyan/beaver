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


