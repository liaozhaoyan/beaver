import requests

url = 'https://www.baidu.com'

try:
    response = requests.head(url)
    response.raise_for_status()  # 检查请求是否成功
    print('Status Code:', response.status_code)
    print('Response Headers:')
    print(response.headers)
except requests.exceptions.RequestException as e:
    print('An error occurred:', e)