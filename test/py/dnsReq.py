import socket


def single():
    s = socket.socket()

    s.connect(("127.0.0.1", 3383))
    domain = "www.baidu.com"
    s.send(domain.encode())
    print(s.recv(80))
    s.close()
    print("test ok.")


if __name__ == "__main__":
    single()
