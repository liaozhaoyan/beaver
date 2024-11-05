import os
import time

# FIFO路径
fifo_path = '/tmp/beaver_fifo'

# 创建命名管道（如果它不存在）
if not os.path.exists(fifo_path):
    os.mkfifo(fifo_path)

# 打开命名管道进行写入
with open(fifo_path, 'w') as fifo:
    while True:
        # 写入数据
        fifo.write("hello from beaver!")
        fifo.flush()  # 确保数据被写入
        time.sleep(1)  # 每秒写一次