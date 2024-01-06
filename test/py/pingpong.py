import socket

s = socket.socket()

s.connect(("127.0.0.1", 3382))

while True:
    stream = "abcdefg"
    s.send(stream.encode())
    r = s.recv(1024).decode()
    assert(stream == r)