#!/usr/bin/python2
import os
import sys


confBase = """
worker:
  - number: 1   # worker process
    funcs:
      - func: "httpServer"
        mode: "TCP"
        bind: "0.0.0.0"
        port: 2000
        entry: "hello"  # 
"""


def createProject(projName):
    os.mkdir(projName)
    confPath = os.path.join(projName, "main")
    os.mkdir(confPath)
    confFile = os.path.join(confPath, "config.yaml")
    with open(confFile, "a") as f:
        f.write(confBase)
    os.popen("mkdir -p %s" % os.path.join(projName, "lua/app"))
    print("project %s is created." % projName)


if __name__ == '__main__':
    assert len(sys.argv) >= 3, "need path and project name args"
    assert os.path.isdir(sys.argv[1]), "%s is not a dir" % sys.argv[1]
    projName = os.path.join(sys.argv[1], sys.argv[2])
    assert not os.path.exists(projName), "%s is already exist." % projName
    createProject(projName)