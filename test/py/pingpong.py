import socket
import random


def single():
    s = socket.socket()

    s.connect(("127.0.0.1", 3382))
    i = 0
    loop = random.randint(8000, 12000)
    while i < loop:
        stream = "abcdefg1234567" * random.randint(1, 256)
        s.send(stream.encode())

        r = ""
        l = len(stream)
        size = 0
        while size < l:
            v = s.recv(l - size).decode()
            if len(v) == 0:
                break
            r += v
            size = len(r)
        assert(stream == r)
        i += 1

    s.close()
    print("test ok.")


if __name__ == "__main__":
    single()
