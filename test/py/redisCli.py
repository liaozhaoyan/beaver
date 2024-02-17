import requests

cmdUrl = "http://172.16.0.129:3385/rcmd"
pipeUrl = "http://172.16.0.129:3385/rcmds"

data = "set hello:world1."
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
assert(response.text == "OK")

data = "get hello"
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
assert(response.text == "world1.")

data = "del people"
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
assert(response.text == "1")

data = "hset people:name:Sam:age:28:sex:male"
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
assert(response.text == "3")

data = "hgetall people"
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
assert(response.text == '["name","Sam","age","28","sex","male"]')

data = "set hello:world2.\nget hello\nset world:world3.\nget world"
response = requests.post(pipeUrl, data=data)
assert(response.status_code == 200)
assert(response.text == '["OK","world2.","OK","world3."]')

data = "info"
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
print(response.text)

data = "ping"
response = requests.post(cmdUrl, data=data)
assert(response.status_code == 200)
print(response.text)