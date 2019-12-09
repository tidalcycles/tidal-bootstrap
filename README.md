tidal-bootstrap
===============

Please note that this is an experimental installation script. Run
under your own risk. If you have problems, please join us on the
[#tidal-install](https://chat.toplap.org/channel/tidal-install) chat
channel and we'll try to help. We'd be very happy to hear about
successes too!

Summary
-------

`tidal-bootstrap` is small shell script which attempts to automate the
installation process of the [TidalCycles](http://tidalcycles.org/)
live coding environment under Mac OS X and Linux (on Debian-derived systems, e.g. Ubuntu, Mint).

`tidal-bootstrap` installs the tools mentioned in TidalCycles [installation](https://tidalcycles.org/index.php/Installation) guide.

The script checks if the following programs are installed on the system, and installs them if they are missing.

* SuperCollider (and SuperDirt)
* Atom (and the TidalCycles plugin)
* ghci (ghcup)
* The [Tidal library](https://hackage.haskell.org/package/tidal)

Running
-------

You should be able to run the install script by opening a terminal window, pasting in the following and pressing enter:

```
curl https://tidalcycles.org/tidal-bootstrap.sh -sSf | sh
```

(It will probably ask for your password at some point. As you type, characters won't be echoed to the screen, so you'll have to look at your keys and do your best!)
