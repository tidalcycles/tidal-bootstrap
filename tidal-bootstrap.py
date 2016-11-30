#!/usr/bin/env python

import os
import sys
import urllib
import urlparse
# import time
# from queue import Queue
import Queue
from threading import Thread

urls = {
    'SuperCollider.app': "https://github.com/supercollider/supercollider/releases/download/Version-3.8.0/SuperCollider-3.8.0-OSX.zip",
    'Atom.app': "https://atom.io/download/mac",
    'ghci': "https://haskell.org/platform/download/8.0.1/Haskell%20Platform%208.0.1%20Full%2064bit-signed-a.pkg",
}


class DownloadWorker(Thread):
    def __init__(self, queue):
        Thread.__init__(self)
        self.queue = queue

    def run(self):
        try:
            while True:
                # Get the work from the queue
                dep = self.queue.get()
                downloadDependecy(dep)
                self.queue.task_done()
        except KeyboardInterrupt:
            print 'Interrupted'


# mimic unix which program
def which(program):
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)

    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file
    return None


def appExists(app_name):
    def isFile(path):
        return os.path.isdir(path) and path.endswith('.app')

    app_dirs = ['/Applications', os.path.expanduser('~/Applications')]

    for dir in app_dirs:
        app_path = os.path.join(dir, app_name)
        return isFile(app_path)

    return None


def downloadProgress(count, blockSize, totalSize):
    percent = int(count * blockSize * 100 / totalSize)
    sys.stdout.write("\r" + "..%d%%" % percent)
    sys.stdout.flush()


def filenameFromURL(url):
    """Return the filename from an URL"""
    url = urlparse.urlparse(url).path
    url = urllib.unquote(url).decode('utf8')
    path, filename = os.path.split(url)
    return filename


def checkStatus(program):
    success = u'\u2713'
    error = u'\u2717'

    if appExists(program) or which(program):
        print success, program
        return True
    else:
        print error, program
        return False


def downloadDependecy(dep):
    """Downloads an app dependency"""

    # store all downloaded in the current directory
    download_dir = os.path.abspath('./tidal-deps')
    # Create a temporary dir where we will download all assets
    if not os.path.exists(download_dir):
        os.makedirs(download_dir)

    print "Downloading dependency:", dep

    url = urls[dep]
    dl_name = filenameFromURL(url)
    dl_path = os.path.join(download_dir, dl_name)
    urllib.urlretrieve(url,
                       dl_path,
                       downloadProgress)


def main():
    # Create a queue to communicate with the worker threads
    queue = Queue.Queue()
    # Create worker threads
    for x in range(len(urls.keys())):
        worker = DownloadWorker(queue)
        # Setting daemon to True will let the main thread exit
        # even though the workers are blocking
        worker.daemon = True
        worker.start()

    print "Checking dependencies..\n"

    for program in urls.keys():
        exists = checkStatus(program)
        if not exists:
            queue.put(program)

    # Causes the main thread to wait for the
    # queue to finish processing all the tasks
    queue.join()


if __name__ == '__main__':
    main()
