tidal-bootstrap
===============

Requirements
------------

* [homebrew](http://brew.sh/)
* Python 2.x (should already be present on OS X systems)

Summary
-------

`tidal-bootstrap` is small python script which attempts to ease the installation process of the [TidalCycles](http://tidalcycles.org/) programming environment. **It only works on OS X for the moment.**

`tidal-bootstrap` installs the tools mentioned in TidalCycles [Getting Started](http://tidalcycles.org/getting_started.html) guide.

The script checks if the following programs are installed on the system:

* SuperCollider
* Atom
* ghci (haskell-platform)

If it finds that any of the dependencies are missing, it will ask if the user would like to download the missing dependencies.

Additionally, it will install the [Tidal package](https://hackage.haskell.org/package/tidal), the [Atom plugin](https://atom.io/users/tidalcycles), and check the presence of the SuperCollider [SuperDirt quark](https://github.com/musikinformatik/SuperDirt).

It uses [homebrew](http://brew.sh/) (specifically [homebrew-cask](https://github.com/caskroom/homebrew-cask)) to fetch and install the different dependencies.

Troubleshooting
---------------

If Haskell < 7.10 is currently installed, you will not be able to install Tidal because [Haskell 7.8 broke in El Capitan](https://ghc.haskell.org/trac/ghc/blog/weekly20150721#MacOSXElCapitansupport). Uninstall ghc and cabal-install and try again. It may also be necessary to delete all libraries installed with the old cabal by running `rm -rf ~/.cabal`.
