#!/usr/bin/env python

import os
import sys
import subprocess

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


success_mark = Colorize.OKGREEN + u'\u2713' + Colorize.ENDC
error_mark = Colorize.FAIL + u'\u2717' + Colorize.ENDC


def parse_input():
    """ Parse user input """
    # raw_input returns the empty string for "enter"
    yes = set(['yes', 'y',  'ye',  ''])
    no = set(['no', 'n'])

    while True:
        try:
            choice = raw_input('-> ').lower()
            if choice not in yes and choice not in no:
                print "Please respond with 'yes' or 'no'"
                continue
            else:
                if choice in yes:
                    return True
                elif choice in no:
                    return False
        except (KeyboardInterrupt, SystemExit):
            sys.exit(0)


def is_installed(program):
    if app_exists(program) or which(program):
        print '\t' + success_mark, program
        return True
    else:
        print '\t' + error_mark, program
        return False


def setup_cask():
    print "Setting up brew cask.. (this could take a while)"
    return_code = subprocess.call(['brew', 'tap', 'caskroom/cask'])
    if return_code != 0:
        print "Could not setup `brew cask`, quitting."
        sys.exit(0)


def check_brew():
    if which('brew'):
        # Get brew cask
        setup_cask()
        return
    else:
        print "\nThis script needs `brew` to run!"
        print "Please install homebrew and run this script again."
        print "Follow the instructions on the homebrew website:\n"
        print "\t" + "http://brew.sh/"
        sys.exit(0)


def welcome():
    print "==============="
    print "TIDAL BOOTSTRAP"
    print "==============="
    print "\nThis script will check if you have all dependencies (programs)"
    print "installed on your system to begin working with TidalCycles.\n"
    print ("If a dependency is missing the script will try "
           + "to download and install it for you.\n")

    print "Do you wish to continue?"
    print "y/n (or press Enter to continue)\n"

    if parse_input():
        return
    else:
        print "Okay, qutting."
        sys.exit(0)


# TODO: Make this parallel using subprocess.Popen
def install_dep(cmd, name):
    print "Installing:", name
    if name == 'ghci':
        name = 'haskell-platform'

    command = cmd.split()
    command.append(name)

    return_code = subprocess.call(command)
    if return_code != 0:
        print "Could not install", name, "quitting."
        sys.exit(0)


def install_app_dependencies(targets):
    # See if user has installed homebrew, otherwise we quit here
    check_brew()

    for program in targets:
        name, ext = os.path.splitext(program)
        install_dep('brew cask install', name.lower())

    print "\nAll app dependencies installed!"


def check_packages():
    print "\nChecking packages.."
    has_tidal = check_tidal()
    has_atom_pkg = check_atom_plugin()
    has_sc_quark = check_sc_quarks()

    found_pkgs = [has_tidal, has_atom_pkg, has_sc_quark]

    if found_pkgs.count(True) == 3:
        print Colorize.OKGREEN + "\nAll packages are installed!"+Colorize.ENDC
    elif not has_tidal or not has_atom_pkg:
        print (
            Colorize.WARNING
            + "Sorry, all packages could not be installed"
            + Colorize.ENDC
        )

        if not has_tidal:
            print "Tidal cabal package could not be installed"
        if not has_atom_pkg:
            print "Atom tidal package could not be installed"

        print ("Visit: http://tidalcycles.org/getting_started.html "
               + "and install them using the instructions found there")

    if not has_sc_quark:
        print ("Please open the file: "
               + Colorize.OKGREEN
               + "install-superdirt-quark.scd"
               + Colorize.ENDC
               + " in SuperCollider to install SuperDirt")


def check_atom_plugin():
    print "Checking if tidal atom package is installed.."
    try:
        output = subprocess.check_output('apm list | grep tidal',
                                         shell=True)
    except subprocess.CalledProcessError, err:
        output = err.output

    if output:
        print success_mark, output
        return True
    else:
        return_code = subprocess.call(['apm', 'install', 'tidalcycles'])
        if return_code != 0:
            print "Could not install tidalcycles atom package!"
            print "Try to install from Atom.app instead"
            return False
        else:
            return True


def check_tidal():
    print "Checking if tidal package is installed.."
    try:
        output = subprocess.check_output('ghc-pkg list | grep tidal',
                                         shell=True)
    except subprocess.CalledProcessError, err:
        output = err.output

    if output:
        print success_mark, output
        return True
    else:
        print "Installing tidal.."
        return_code = subprocess.call(['cabal', 'install', 'tidal'])
        if return_code != 0:
            print "Could not install tidal!"
            return False
        else:
            return True


def check_sc_quarks():
    print "Checking if SuperDirt quark is installed.."
    dirt_path = os.path.expanduser(
        ('~/Library/Application Support/SuperCollider'
         + '/downloaded-quarks/SuperDirt')
    )

    if not os.path.isdir(dirt_path):
        print "SuperDirt quark was not found"
        return False
    else:
        print success_mark, dirt_path
        return True


def main():
    welcome()
    print "Checking dependencies..\n"

    targets = []

    for program in deps:
        installed = is_installed(program)
        if not installed:
            targets.append(program)

    if targets:
        print "\nThe following dependencies needs to be installed:\n"
        for dep in targets:
            print Colorize.OKBLUE + '\t- ' + dep + Colorize.ENDC

        print "\nDo you wish to install them?"
        print "y/n (or press Enter to accept)\n"

        if parse_input():
            install_app_dependencies(targets)
        else:
            print "Okay, quitting."
            sys.exit(0)
    else:
        print "\nAll app dependencies found!"

    # See if we need to install additional packages
    check_packages()


if __name__ == '__main__':
    main()
