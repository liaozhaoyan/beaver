import socket
import random


def single():
    s = socket.socket()

    s.connect(("127.0.0.1", 3382))
    i = 0
    while i < 1000:
        stream = "abcdefg1234567" * random.randint(1, 8192)
        s.send(stream.encode())

        r = ""
        l = len(stream)
        size = 0
        while size < l:
            r += s.recv(l - size).decode()
            size = len(r)
        assert(stream == r)
        i += 1

    print("test ok.")


if __name__ == "__main__":
    single()
