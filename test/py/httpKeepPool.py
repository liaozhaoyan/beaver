import threading
import requests
import random
import time

origUrl = "http://127.0.0.1:3385/keep"
threadNum = 120

def get(url):
    try:
        print("get start", url)
        res = requests.get(url, timeout=random.randint(2, 8))
        print("get success, %d, %s" % (res.status_code, len(res.content)))
        if len(res.content) < 5000:
            print(res.content)
    except Exception as e:
        print(str(e))
        time.sleep(3)

while True:
    threads = []

    t1 = time.time()
    for i in range(threadNum):
        t = threading.Thread(target=get, args=(origUrl,))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    print("all done, use", time.time() - t1)
    time.sleep(0.1 + random.randint(0, 8)/100)
