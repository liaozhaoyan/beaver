from multiprocessing import Process
import random
import pingpong


class Cpp(Process):
    def __init__(self):
        super(Cpp, self).__init__()
        self.start()

    def run(self):
        print("start ", self.pid)
        pingpong.single()


def loop():
    while True:
        ps = []
        for i in range(random.randint(16, 32)):
            ps.append(Cpp())
        for p in ps:
            p.join()


if __name__ == "__main__":
    loop()