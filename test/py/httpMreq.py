from multiprocessing import Process
import random
import httpReqs


class Cpp(Process):
    def __init__(self):
        super(Cpp, self).__init__()
        self.start()

    def run(self):
        print("start ", self.pid)
        httpReqs.single(random.randint(10, 50))
        print("done ", self.pid)

def loop():
    while True:
        ps = []
        for i in range(random.randint(16, 64)):
            ps.append(Cpp())
        for p in ps:
            p.join()


if __name__ == "__main__":
    loop()