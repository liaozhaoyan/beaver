import requests

url = "http://172.16.0.129:3385/gc"
res = requests.get(url)
print(res.content)