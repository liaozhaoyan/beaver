import requests
import random
import time
from requests.exceptions import Timeout

urls = [
        "http://172.16.0.129:3385/bing",
        "http://172.16.0.129:3385/baidu",
        "http://172.16.0.129:3385/instance"
        ]


def single(loop, body=False):
    for i in range(loop):
        for url in urls:
            try:
                res = requests.get(url, timeout=random.randint(10, 20))
            except Timeout as e:
                print("catched tmo.")
            if body:
                print(res.content)


if __name__ == "__main__":
    while True:
        single(1, True)
        time.sleep(2)
