tidal-bootstrap
===============

Please note that this is an experimental installation script. Run
under your own risk. If you have problems, please join us on the
[#tidal-install](https://chat.toplap.org/channel/tidal-install) chat
channel and we'll try to help. We'd be very happy to hear about
successes too!

Summary
-------

`tidal-bootstrap` is small shell script which attempts to ease the
installation process of the [TidalCycles](http://tidalcycles.org/)
programming environment under Mac OS X.

`tidal-bootstrap` installs the tools mentioned in TidalCycles [Getting Started](http://tidalcycles.org/getting_started.html) guide.

The script checks if the following programs are installed on the system, and installs them if they are missing.

* SuperCollider (and SuperDirt)
* Atom (and the TidalCycles plugin)
* ghci (ghcup)
* The [Tidal library](https://hackage.haskell.org/package/tidal)

Running
-------

You should be able to run this script by opening a terminal window, pasting in the following and pressing enter:

```
curl https://raw.githubusercontent.com/tidalcycles/tidal-bootstrap/master/tidal-bootstrap.command -sSf | sh
```
