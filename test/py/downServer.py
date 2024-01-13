import socketserver
import random

g_count = 1


def recvLen(sock, size):
    ret = ""
    l = 0

    while l < size:
        ret += sock.recv(size - l).decode()
        l = len(ret)
    return ret


class MyTCPHandler(socketserver.BaseRequestHandler):

    def handle(self):
        global g_count
        print("new Cli.", g_count)
        g_count += 1
        data = "abcdefg hijk"
        for i in range(random.randint(80, 120)):
            s = data * random.randint(1, 2000)
            self.request.sendall(s.encode())
            ret = recvLen(self.request, len(s))
            assert(ret == s.upper())


if __name__ == "__main__":
    HOST, PORT = "0.0.0.0", 3385

    # Create the server, binding to localhost on port 9999
    with socketserver.ThreadingTCPServer((HOST, PORT), MyTCPHandler) as server:
        # Activate the server; this will keep running until you
        # interrupt the program with Ctrl-C
        server.serve_forever()