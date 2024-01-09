import socketserver


class MyTCPHandler(socketserver.BaseRequestHandler):

    def handle(self):
        print("new Cli.")
        while 1:
            data = self.request.recv(16384)
            if len(data) == 0:
                break
            self.request.sendall(data.upper())


if __name__ == "__main__":
    HOST, PORT = "localhost", 3385

    # Create the server, binding to localhost on port 9999
    with socketserver.ThreadingTCPServer((HOST, PORT), MyTCPHandler) as server:
        # Activate the server; this will keep running until you
        # interrupt the program with Ctrl-C
        server.serve_forever()