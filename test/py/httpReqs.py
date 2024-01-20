import requests

urls = ["http://172.16.0.129:3385/bing",
        "http://172.16.0.129:3385/baidu",
        "http://172.16.0.129:3385/instance"
        ]


def single(loop):
    for i in range(loop):
        for url in urls:
            res = requests.get(url)
            assert res.status_code == 200


if __name__ == "__main__":
    single(100)
