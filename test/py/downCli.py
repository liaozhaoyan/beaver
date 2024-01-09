import socket


def downTest():
    HOST, PORT = "localhost", 3384

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        # Connect to server and send data
        sock.connect((HOST, PORT))

        while 1:
            sock.settimeout(10)
            s = sock.recv(16384).decode()
            if len(s) == 0:
                break
            sock.sendall(s.upper().encode())


if __name__ == "__main__":
    downTest()
    print("test ok.")