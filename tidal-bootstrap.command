#!/bin/bash
# Authors: James Campbell, Alex McLean
# Licence: GPLv3
# Date: September 2019
# Last Updated: October 2019
# Contact: james@jamescampbell.us / alex@slab.org
# What: tidalcycles installer script for OSX

#### COLORS
COLOR_PURPLE='\033[0;35m'
normal='\033[0m'

#### CHECK FOR MAC OS
if [[ "$OSTYPE" == "darwin"* ]]; then
	printf "$COLOR_PURPLE[0]$normal Mac OS detected, moving forward with installation...\n"
else
	echo "Mac OS not detected, this script is for Mac OS or OSX only." && exit 1
fi

#### CHECK FOR GIT
if command -v git 2>/dev/null; then
	printf "$COLOR_PURPLE[1]$normal git found, skipping...\n"
else
	printf "$COLOR_PURPLE[1]$normal 'git' required, installing commandline tools..."
	printf "** Please click 'install' when a popup appears, and wait until it finishes installing. **\n"
	/usr/bin/xcode-select --install
        printf "\nWhen that's done, click on this window and press enter to continue."
        read -r answer </dev/tty
fi

#### CHECK FOR HASKELL
if [ -e ~/.ghcup/bin/cabal ]; then
	printf "$COLOR_PURPLE[2]$normal Haskell found, skipping install of that...\n"
else
	printf "$COLOR_PURPLE[2]$normal Installing Haskell (via 'ghcup')...\n"
        curl https://get-ghcup.haskell.org -sSf | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 sh
        if [ $(grep -c ghcup ~/.bashrc) -ne 0 ]; then
            printf "$COLOR_PURPLE[2.1]$normal Adding ghcup initialisation to ~/.bashrc...\n"
            echo '. $HOME/.ghcup/env' >> "$HOME/.bashrc"
        fi
fi

#### INSTALL TIDALCYCLES
printf "$COLOR_PURPLE[3]$normal Congratulations, you have all the pre-reqs...\n"
echo "Installing tidalcycles haskell library (via cabal)..."
echo ""
. "$HOME/.ghcup/env"
cabal v2-update
cabal v2-install tidal --lib

##

#### INSTALL ATOM
if [ -d "/Applications/Atom.app" ]; then
    printf "$COLOR_PURPLE[4]$normal Atom already installed, skipping...\n"
else
    printf "$COLOR_PURPLE[4]$normal Installing Atom...\n"
    curl -Lk https://github.com/atom/atom/releases/download/v1.40.1/atom-mac.zip --output /tmp/atom.zip
    unzip -q "/tmp/atom.zip" -d /Applications
    rm /tmp/atom.zip
fi

printf "$COLOR_PURPLE[6]$normal Installing atom TidalCycles plugin...\n"
/Applications/Atom.app/Contents/Resources/app/apm/bin/apm install tidalcycles

#### INSTALL SUPERCOLLIDER
if [ -d "/Applications/SuperCollider.app" ]; then
    printf "$COLOR_PURPLE[7]$normal SuperCollider already installed, skipping...\n"
else
    printf "$COLOR_PURPLE[7]$normal Installing SuperCollider...\n"
    curl -Lk https://github.com/supercollider/supercollider/releases/download/Version-3.10.3/SuperCollider-3.10.3-macOS-signed.zip --output /tmp/sc3.zip
    unzip -q "/tmp/sc3.zip" "SuperCollider/SuperCollider.app/*" -d /tmp/testsc
    mv /tmp/testsc/SuperCollider/SuperCollider.app /Applications
    rm /tmp/sc3.zip
fi

if [ -e "~/Library/Application\ Support/SuperCollider/Extensions/StkInst.scx" ]; then
    printf "$COLOR_PURPLE[8]$normal sc3-plugins already installed, skipping...\n"
else
    #### INSTALL PLUGINS
    printf "$COLOR_PURPLE[8]$normal Installing SuperCollider Plugins...\n"
    curl -Lk https://github.com/supercollider/sc3-plugins/releases/download/Version-3.10.0/sc3-plugins-3.10.0-macOS.zip --output /tmp/sc3plugins.zip
    mkdir -p ~/Library/Application\ Support/SuperCollider/Extensions/
    unzip -q /tmp/sc3plugins.zip -d ~/Library/Application\ Support/SuperCollider/Extensions/
    rm /tmp/sc3plugins.zip
fi

#### INSTALL SUPERDIRT
echo "$COLOR_PURPLE[9]$normal Installing the SuperDirt synths and samples (will take some time..)"
echo 'Quarks.install("https://github.com/musikinformatik/SuperDirt.git");"SuperDirt installation complete!".postln;0.exit;' | /Applications/SuperCollider.app/Contents/MacOS/sclang

echo "Tidal and SuperDirt should now be installed!\n\n"

echo "Please log out and in again to complete the set up.\n\n"

echo "You can then follow the instructions here to start everything up for the first time:"
echo "  https://tidalcycles.org/index.php/Start_tidalcycles_and_superdirt_for_the_first_time"
echo "Enjoy!"
exit 0
