# tidal-bootstrap

This installation script is an "ad-hoc" solution. Effort is made to ensure it works, but it does not have robust error detection and hasn't been fully tested on all current macOS versions. If you have problems, please join us on the
[#tidal-install](https://chat.toplap.org/channel/tidal-install) chatchannel and we'll try to help. We'd be very happy to hear about
successes too!

## Summary
### OS support
- Tested on Mac Intel: Big Sur
- Install may work on Silicon, but it has yet to be validated and tested.

#### Description
`tidal-bootstrap` is shell script which automates the installation process of the [TidalCycles](http://tidalcycles.org/)
live coding environment under Mac OS X.

`tidal-bootstrap` installs the components covered in the TidalCycles [MacOS installation](https://tidalcycles.org/docs/getting-started/macos_install) guide.

The script checks if the following programs are installed on the system, and installs them if they are missing.

* SuperCollider, SuperDirt, sc-3 plugins
* ghci (ghcup)
* The [Tidal library](https://hackage.haskell.org/package/tidal)
* Pulsar text editor
    - NOTE: The Pulsar package (plugin) for Tidalcycles is not yet part of this installation. Manual installation is needed. See the [Pulsar page] (https://tidalcycles.org/docs/getting-started/editor/Pulsar).

### Running
You should be able to run the install script by opening a terminal window, pasting in the following and pressing enter:

```
curl https://raw.githubusercontent.com/tidalcycles/tidal-bootstrap/master/tidal-bootstrap.command -sSf | sh
```

It will ask for your password - from the "sudo" command.
