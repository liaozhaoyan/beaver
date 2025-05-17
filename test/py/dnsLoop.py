import requests
import time

url = 'http://127.0.0.1:3385/dns'

domains = ["www.baidu.com", 
           "www.google.com", 
           "www.sina.com.cn", 
           "www.qq.com", 
           "www.163.com"]

i = 0
while True:
    for domain in domains:
        start = time.time()
        response = requests.get(url, params={"domain": domain})
        end = time.time()
        # print(f"{domain}: {response.text} {end - start}")
    i += 1
    print("loop: ", i)
    time.sleep(1)