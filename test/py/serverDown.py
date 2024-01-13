import socket
import threading
import random


def recvLen(sock, size):
    ret = ""
    l = 0

    while l < size:
        s = sock.recv(size - l).decode()
        if len(s) == 0:
            break
        ret += s
        l = len(ret)
    return ret


def process_conn(sock, address):
    print("process for %s" % str(address))

    data = "abcdefg hijk"
    for i in range(random.randint(80, 120)):
        s = data * random.randint(1, 2000)
        sock.sendall(s.encode())
        ret = recvLen(sock, len(s))
        assert(ret == s.upper())
    print("close socket..")
    sock.close()


def handle_conn(sock, address):
    t = threading.Thread(target=process_conn, args=(sock, address))
    t.start()


def main():
    # 1. create socket
    tcp_server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # 2. bind local information
    tcp_server_socket.bind(("0.0.0.0", 3385))
    # 3.
    tcp_server_socket.listen()
    # 4. accept connection from client
    while True:
        new_client_socket, client_addr = tcp_server_socket.accept()
        handle_conn(new_client_socket, client_addr)


if __name__ == '__main__':
    main()
