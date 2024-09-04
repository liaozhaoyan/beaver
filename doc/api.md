# 1、beaver 接口文档
这是beaver 的api 接口说明

# 2、基础库功能接口
## 2.1、system 库
system 提供 了一些lua基础系统相关的功能
- require("common.system")
### 2.1.1、 deepcopy
deepcopy 函数提供对lua table 的深拷贝功能
* 入参1 : 待拷贝的对象 table 类型
* 出参1 : 拷贝后的对象 table 类型


# 3、其它接口
## 3.1、编码接口
beaver 的编码通过调用openssl 库的相关函数实现 
- require("common.digest")

### 3.1.1、md5
md5 函数提供对字符串的md5 计算功能
* 入参1 : 待计算的字符串 string 类型
* 出参1 : 计算结果 string 类型
