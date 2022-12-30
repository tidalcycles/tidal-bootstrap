# tidal-bootstrap

This installation script is an "ad-hoc" solution. Effort is made to ensure it works, but it does not have robust error detection and hasn't been fully tested on all current macOS versions. If you have problems, please join us on the
[#tidal-install](https://chat.toplap.org/channel/tidal-install) chat channel and we'll try to help. We'd be very happy to hear about successes too!

## Summary
### OS support
- Tested on Mac Intel: Big Sur, Monterey
- Install may work on Silicon, but it has yet to be validated and tested.
- Support for Linux has been removed, the script will exit.

#### Description
`tidal-bootstrap` is shell script which automates the installation steps for [TidalCycles](http://tidalcycles.org/) live coding environment under Mac OS X.

`tidal-bootstrap` installs the components covered in the TidalCycles [MacOS installation](https://tidalcycles.org/docs/getting-started/macos_install) guide.

The script checks if the following programs are installed on the system, and installs them if they are missing:

- Xcode command line tools (with git)
- [Haskell](https://www.haskell.org/) Language ([Ghcup](https://www.haskell.org/ghcup/))
- [cabal](https://www.haskell.org/cabal/): package system for Haskell and Tidalcycles
- The Tidal Pattern engine (Tidal Cycles itself), with the important BootTidal.hs file
- [Pulsar](https://pulsar-edit.dev/): Text editor
    - [tidalcycles plugin](https://github.com/tidalcycles/atom-tidalcycles) for Pulsar
- [SuperCollider](https://supercollider.github.io/) for backend audio generation, and:
    - [SuperDirt](https://github.com/musikinformatik/SuperDirt): sample library used by tidal
    - [sc-3 plugins](https://github.com/supercollider/sc3-plugins): unit generator plugins

### Running tidal-bootstrap
For best results, first install the Apple Xcode command line tools.

```
/usr/bin/xcode-select --install
```
Then run this:
```
curl https://raw.githubusercontent.com/tidalcycles/tidal-bootstrap/master/tidal-bootstrap.command -sSf | sh
```

Note: if there are failures, the script can be run again. Correctly installed components will be skipped.

### sh profiles
macOS by default does not install a shell profile (.bashrc for bash, .zshrc for zsh). Haskell requires a profile file to be present. This script uses the "touch" command to create these if they are not there then adds a command that will add the ghcup path to your PATH, by running `~/.ghcup/env`
