#!/usr/bin/env python

import os
import sys

deps = [
    'SuperCollider.app',
    'Atom.app',
    'ghci'
]


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


def app_exists(app_name):
    def is_file(path):
        return os.path.isdir(path) and path.endswith('.app')

    app_dirs = ['/Applications', os.path.expanduser('~/Applications')]

    for dir in app_dirs:
        app_path = os.path.join(dir, app_name)
        return is_file(app_path)

    return None


class Colorize:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''


def parse_input():
    """ Parse user input """
    # raw_input returns the empty string for "enter"
    yes = set(['yes', 'y',  'ye',  ''])
    no = set(['no', 'n'])

    while True:
        choice = raw_input('-> ').lower()
        if choice not in yes and choice not in no:
            print "Please respond with 'yes' or 'no'"
            continue
        else:
            if choice in yes:
                return True
            elif choice in no:
                return False


def is_installed(program):
    success = Colorize.OKGREEN + u'\u2713' + Colorize.ENDC
    error = Colorize.WARNING + u'\u2717' + Colorize.ENDC

    if app_exists(program) or which(program):
        print '\t' + success, program
        return True
    else:
        print '\t' + error, program
        return False


def check_brew():
    if which('brew'):
        return
    else:
        print "\nThis script needs `brew` to run!"
        print "Please install homebrew and run this script again."
        print "Follow the instructions on the homebrew website:\n"
        print "\t" + "http://brew.sh/"
        sys.exit(0)


targets = []


def main():
    check_brew()

    print "\nTIDAL BOOTSTRAP\n"
    print "Checking dependencies..\n"

    for program in deps:
        installed = is_installed(program)
        if not installed:
            targets.append(program)

    if targets:
        print "\nThe following dependencies needs to be installed:\n"
        for dep in targets:
            print '\t* ' + dep

    print "\nDo you wish to install them?"
    print "y/n (or press Enter to accept)\n"

    if parse_input():
        # install_dependencies()
        print "Install"
    else:
        print "Okay, quitting"


if __name__ == '__main__':
    main()
