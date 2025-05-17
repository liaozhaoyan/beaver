import requests
import gzip
import zlib
import io

url = 'http://127.0.0.1:3385/baidu'

# 原始数据（例如 JSON）
data = b'{"key": "value"}'

# 压缩为 Gzip 格式
buffer = io.BytesIO()
with gzip.GzipFile(fileobj=buffer, mode='wb') as f:
    f.write(data)
compressed_data = buffer.getvalue()

# 发送请求
headers = {
    'Content-Type': 'application/json',
    'Content-Encoding': 'gzip'
}
response = requests.get(url, data=compressed_data, headers=headers)
print(response.status_code)


compressed_data = zlib.compress(data)

# 发送请求
headers = {
    'Content-Type': 'application/json',
    'Content-Encoding': 'deflate'
}
response = requests.get(url, data=compressed_data, headers=headers)
print(response.status_code)

headers = {
    "Accept-Encoding": "gzip"  # 仅接受 gzip 格式的响应内容
}
response = requests.get(url, headers=headers)