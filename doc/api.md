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

### 2.1.2、dump
dump函数提供将Lua表以易读的格式打印为字符串的功能，常用于调试和日志记录 
* 入参1: 待打印的表, table类型
* 出参1: 格式化后的表字符串, string类型

### 2.1.3、dumps
dumps函数类似于dump，但它直接将格式化后的表字符串输出至控制台 
* 入参1: 待打印的表, table类型
* 无直接返回值，但会在控制台显示格式化的表内容

### 2.1.4、coReport
coReport函数用于报告协程执行失败的信息，提供简洁的错误信息输出 
* 入参1: 协程对象, coroutine类型
* 入参2: 可选错误信息, string类型
* 出参: 若协程执行成功则返回true，否则返回错误信息或默认的错误报告

### 2.1.5、liteAssert
liteAssert函数提供轻量级的断言功能，用于检查条件是否满足，不满足时抛出错误 
* 入参1: 条件表达式, 布尔类型
* 其余入参: 错误信息的格式化字符串及其参数
* 无返回值，条件不满足时抛出错误

### 2.1.6、pcall
pcall函数提供安全调用，捕获并处理函数执行期间的错误 
* 入参1: 要调用的函数, function类型
* 其余入参: 传递给函数的参数
* 出参1: 如果没有错误发生则为true，否则为false
* 出参2: 在错误情况下为错误信息，否则为函数的返回值

### 2.1.7、lastError
lastError函数返回最近一次由funcReport捕获的错误堆栈信息 
* 无入参
* 出参1: 错误堆栈信息, string类型

### 2.1.8、reverseTable
reverseTable函数用于反转一个表的元素顺序 
* 入参1: 待反转的表, table类型
* 无直接返回值，但会修改原表的元素顺序

### 2.1.9、keyIsIn
keyIsIn函数检查指定键是否存在于表中 
* 入参1: 表, table类型
* 入参2: 键, any类型
* 出参: 如果键存在则为true，否则为false

### 2.1.10、valueIsIn
valueIsIn函数检查指定值是否存在于表的值集中 
* 入参1: 表, table类型
* 入参2: 值, any类型
* 出参: 如果值存在则为true，否则为false

### 2.1.11、valueIndex
valueIndex函数查找指定值在表中的索引位置（仅限于连续编号的表） 
* 入参1: 表, table类型
* 入参2: 值, any类型
* 出参: 值的索引位置，如果不存在则为0

### 2.1.12、keyCount
keyCount函数统计表中的键数量 
* 入参1: 表, table类型
* 出参: 键的数量, number类型

### 2.1.13、dictCopy
dictCopy函数创建一个表的浅拷贝（仅复制键值对，不递归拷贝内部表） 
* 入参1: 原表, table类型
* 出参: 拷贝后的表, table类型

### 2.1.14、listMerge
listMerge函数合并多个表为一个新表 
* 入参: 多个表, table类型
* 出参: 合并后的表, table类型

### 2.1.15、hex2ups 和 hex2lows
hex2ups和hex2lows函数分别将每个十六进制字符转换为大写和小写的两位十六进制数 
* 入参1: 十六进制字符串, string类型
* 出参: 转换后的字符串, string类型

### 2.1.16、hexdump
hexdump函数打印缓冲区的十六进制转储，常用于查看二进制数据 
* 入参1: 缓冲区, string类型
* 无直接返回值，但会在控制台显示十六进制转储

### 2.1.17、escHtml 和 escMd
escHtml函数将字符串中的HTML特殊字符转换为HTML实体，escMd用于Markdown文本中的特殊字符转义 
* 入参1: 字符串, string类型
* 出参: 转义后的字符串, string类型

### 2.1.18、timeRfc1123
timeRfc1123函数将时间戳转换为RFC 1123格式的时间字符串 
* 入参1: 时间戳, number类型（可选，默认为当前时间）
* 出参: RFC 1123格式的时间字符串, string类型

### 2.1.19、parseYaml
parseYaml函数读取并解析YAML文件为Lua表 
* 入参1: YAML文件路径, string类型
* 出参: 解析后的Lua表, table类型

### 2.1.20、guid
guid函数生成一个符合UUID格式的全局唯一标识符 
* 无入参
* 出参: UUID字符串, string类型

### 2.1.21、randomStr
randomStr函数生成指定长度的随机字符串，包含数字和大小写字母 
* 入参1: 长度, number类型
* 出参: 随机字符串, string类型


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
b64_encode函数提供Base64编码功能 
* 入参1: 待编码的字符串, string类型
* 出参1: Base64编码后的字符串, string类型

### 3.1.10、b64_decode
b64_decode函数提供Base64解码功能 
* 入参1: 待解码的Base64字符串, string类型
* 出参1: 解码后的字符串, string类型

### 3.1.11、url_encode
url_encode函数提供URL编码功能，遵循RFC3986标准
* 入参1: 待编码的URL字符串, string类型
* 出参1: 编码后的URL字符串, string类型
