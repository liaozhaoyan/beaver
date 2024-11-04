import threading
import requests
import random
import time

origUrl = "http://127.0.0.1:3385/pool"
threadNum = 80

def get(url):
    try:
        print("get start", url)
        res = requests.get(url, timeout=random.randint(10, 20))
        print("get success, %d, %d" % (res.status_code, len(res.content)))
    except Exception as e:
        print(str(e))

while True:
    threads = []

    for i in range(threadNum):
        t = threading.Thread(target=get, args=(origUrl,))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("all done.")
    time.sleep(1)
