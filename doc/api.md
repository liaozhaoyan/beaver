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

### 3.1.2、sha1
sha1函数提供对字符串的SHA-1哈希计算功能
* 入参1: 待计算的字符串, string类型
* 出参1: 计算结果, string类型

### 3.1.3、sha224
sha224函数提供对字符串的SHA-224哈希计算功能
* 入参1: 待计算的字符串, string类型
* 出参1: 计算结果, string类型

### 3.1.4、sha256
sha256函数提供对字符串的SHA-256哈希计算功能
* 入参1: 待计算的字符串, string类型
* 出参1: 计算结果, string类型

### 3.1.5、sha384
sha384函数提供对字符串的SHA-384哈希计算功能
* 入参1: 待计算的字符串, string类型
* 出参1: 计算结果, string类型

### 3.1.6、sha512
sha512函数提供对字符串的SHA-512哈希计算功能
* 入参1: 待计算的字符串, string类型
* 出参1: 计算结果, string类型

### 3.1.7、hmac
hmac函数提供基于密钥的消息认证码计算功能，支持MD5、SHA-1、SHA-224、SHA-256、SHA-384、SHA-512算法
* 入参1: 密钥, string类型
* 入参2: 数据, string类型
* 入参3: 算法标识符, string类型（可选值："md5", "sha1", "sha224", "sha256", "sha384", "sha512"）
* 出参1: 计算结果, string类型

### 3.1.8、hex_encode
hex_encode函数提供将二进制数据转换为十六进制字符串的功能
* 入参1: 待转换的二进制数据, string类型
* 出参1: 十六进制字符串, string类型

### 3.1.9、b64_encode
b64_encode函数提供Base64编码功能。
* 入参1: 待编码的字符串, string类型
* 出参1: Base64编码后的字符串, string类型

### 3.1.10、b64_decode
b64_decode函数提供Base64解码功能。
* 入参1: 待解码的Base64字符串, string类型
* 出参1: 解码后的字符串, string类型

### 3.1.11、url_encode
url_encode函数提供URL编码功能，遵循RFC3986标准
* 入参1: 待编码的URL字符串, string类型
* 出参1: 编码后的URL字符串, string类型
