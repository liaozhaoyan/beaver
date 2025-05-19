import requests

url = "http://127.0.0.1:3385/gc"
res = requests.get(url)
print(res.content)