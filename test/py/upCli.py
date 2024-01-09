import socket
import random


def recvLen(sock, size):
    ret = ""
    l = 0

    while l < size:
        ret += sock.recv(size - l).decode()
        l = len(ret)
    return ret


def upTest():
    HOST, PORT = "localhost", 3384

    data = "abcdefg hijk"
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        # Connect to server and send data
        sock.connect((HOST, PORT))
        for i in range(random.randint(80, 120)):
            s = data * random.randint(1, 2000)
            sock.sendall(s.encode())
            ret = recvLen(sock, len(s))
            assert(ret == s.upper())


if __name__ == "__main__":
    upTest()
    print("test ok.")