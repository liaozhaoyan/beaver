import os
import socket
import os
import random
import time

# 定义 Unix 域套接字的路径
socket_path = '/tmp/uds.sock'

while True:
    # 创建一个 Unix 域套接字
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client_socket:
        # 连接到服务器
        client_socket.connect(socket_path)

        # 准备 5MB 的数据
        data_size = 5 * 1024 * 1024  # 5MB
        data = bytearray(random.getrandbits(8) for _ in range(data_size))  # 生成随机数据

        # 发送数据
        sent_bytes = client_socket.send(data)
        print(f"Sent {sent_bytes} bytes.")
        time.sleep(1)