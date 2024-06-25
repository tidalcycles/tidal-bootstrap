#!/bin/bash
# Authors: James Campbell, Alex McLean, HighHarmonics
# Licence: GPLv3
# Date: September 2019
# Last Updated: Dec 2022 (HighHarmonics)
# Contact: james@jamescampbell.us / alex@slab.org / highharmonics@gmail.com
# What: tidalcycles installer script for OSX
#       tested on: Intel Big Sur 11.7.1
#       not tested on Silicon
# Change Log: Dec, 2022
#   - removed all commands for Linux
#   - replaced Atom install with Pulsar
#       - made Pulsar plugin install a separate section
#   - check for Intel vs Silicon vs anything else
#   - added support for DMG install (Pulsar, SuperCollider), removed zip format
#      if zip format is wanted again, revert via using a previous version
#   - changed cabal command to use v1-install tidal (note: continue to use cabal update)
#   - resolved bug when no shell profile is present (.bashrc or .zshrc) .ghcup/env initialization doesn't load properly
#      done by "touching" both files at top of script and changing test for Haskell install
#   - added test for SuperDirt install
#   - made code format changes per recommendations from shellcheck
#   - updated comments back to screen (user)
#
# Change Log: Jan, 2024
#   - updated SC and SC3 plugins versions for compatibility with Apple Silicon (test on OS X 14.2.1)
#   - unzip SC3 plugins to tmp directory then move SC3Plugins subdirectory to the SC Extensions directory
#     to conform with the file structure in the latest SC3 plugins release ZIP.
#############
## NOTES / known issues
# Install from DMG solution adapted from https://community.jamf.com/t5/jamf-pro/script-for-installing-dmg-pkg-zip-via-curl/m-p/157800
#    needed to get commands for working with macOS DMG file, which requires hdiutil to attach/detach (mount) the DMG
# Pulsar download URLs based on DOWNLOAD links instructions:
#  See https://github.com/pulsar-edit/package-frontend/blob/main/docs/download_links.md
#  Pulsar macOS downloads are currently unsigned.
#    As per https://pulsar-edit.dev/   xattr -cr /Applications/Pulsar.app  command needs to be run.
#  Pulsar plugin install is not reliable - it still may require manual install. 

#### COLORS
COLOR_PURPLE='\033[0;35m'
normal='\033[0m'

### get os values needed for execution
osName=$(uname -s)
myArch=$(uname -m) #intel: x86_64  silicon: arm64

## test for macOS - exit script if not Darwin
if test "${osName}" = "Darwin"; then
    printf "Installing Tidalcycles stack for:\n  os: ${osName}\n  arch: ${myArch}\n\n"
else
    printf "This install script is for use on macOS (Intel or Silicon).\n"
    printf "For Linux or Windows install, see the Install Tidal section in the User Documentation.\n"
    exit 0
fi
###
## determine Intel vs Silicon - set Pulsar download url with query string setting
if test "${myArch}" = "x86_64"; then
    pulsarURL="https://download.pulsar-edit.dev/?os=intel_mac&type=mac_dmg"
elif test "${myArch}" = "arm64"; then
    printf "installing for macOS Silicon\n\n"
    printf "WARNING: Silicon install hasn't had much testing. Certain components may fail.\n\n"
    pulsarURL="https://download.pulsar-edit.dev/?os=silicon_mac&type=mac_dmg"
else
    printf "I don't recognize your system as macOS Intel or Silicon. Aborting script.\n\n"
    exit 0
fi

### GIT - check for git and install via xcode-select if needed
printf "starting install - checking for components\n"
printf "using touch command to ensure shell profiles are present\n"
## Haskell install assumes .bashrc  with macOS no .bashrc or .zshrc is created
touch "$HOME/.bashrc" "$HOME/.zshrc"

if command -v git 2>/dev/null; then
    printf "${COLOR_PURPLE}[1]$normal 'git' already installed.\n"
else
    printf "${COLOR_PURPLE}[1]$normal 'git' is required, installing macOS commandline tools...\n"
    printf "** Please click 'install' when a popup appears, and wait until it finishes installing. **\n"
    /usr/bin/xcode-select --install
    printf "\nWhen that's done, click on this window and press enter to continue."
    read -r answer </dev/tty
fi

#### CHECK FOR HASKELL
if [ -e ~/.ghcup/bin/cabal ]; then
	printf "${COLOR_PURPLE}[2]$normal Haskell found, skipping ...\n"
else
	printf "${COLOR_PURPLE}[2]$normal Installing Haskell (via 'ghcup')...\n"
    curl https://get-ghcup.haskell.org -sSf | BOOTSTRAP_HASKELL_GHC_VERSION=latest BOOTSTRAP_HASKELL_CABAL_VERSION=latest BOOTSTRAP_HASKELL_NONINTERACTIVE=1 sh 2>&1 > /tmp/ghcup-install.log
    ## test to see if cabal exists - then add the env var to shell profiles
    if [ -e "${HOME}/.ghcup/bin/cabal" ]; then
        printf "${COLOR_PURPLE}[2.1]$normal Adding ghcup initialisation to ~/.bashrc and ~/.zshrc...\n"
        echo 'source ${HOME}/.ghcup/env' >> "${HOME}/.bashrc"
        echo 'source ${HOME}/.ghcup/env' >> "${HOME}/.zshrc"
    else
        printf "Error: Haskell pkg mgr cabal not found in ${HOME}/.ghcup/bin. "
    fi
fi

#### INSTALL TIDALCYCLES
printf "${COLOR_PURPLE}[3]$normal You should now have all the required installs for tidal...\n\n"
printf "Installing tidalcycles haskell library (via cabal)...\n"
. "$HOME/.ghcup/env"
cabal update
cabal v1-install tidal

#### INSTALL Pulsar
if [ -d "/Applications/Pulsar.app" ]; then
	printf "${COLOR_PURPLE}[4]$normal Pulsar already installed, skipping...\n"
else
	printf "${COLOR_PURPLE}[4]$normal Installing Pulsar...\n"
## note: zip version not available when script was completed
##     if it becomes available, this section could be reverted use zip
# Creates a tmp directory to mount the .dmg using the hdiutil commands
    pulsarFile="/Applications/Pulsar.app/"
    tmpDir=$(/usr/bin/mktemp -d /tmp/PulsarDMG)
    printf "downloading Pulsar to /tmp \n"
    curl -Lk "${pulsarURL}" --output "${tmpDir}/Pulsar.dmg"
    hdiutil attach "${tmpDir}/Pulsar.dmg" -nobrowse -quiet -mountpoint "${tmpDir}"
    ditto "${tmpDir}/Pulsar.app" "${pulsarFile}"
    sleep 1
    # Detach the dmg and remove the temporary mountpoint
    hdiutil detach -quiet "${tmpDir}"
    printf "\nremoving temp dir \n"
    /bin/rm -rf "${tmpDir}"
# end dmg version. xattr command needed until pulsar provides a signed download
    xattr -cr "${pulsarFile}"
fi

#### INSTALL Plusar plugin - this should work, but it relies on the Pulsar pkg mgr
if [ -d "${HOME}/.pulsar/packages/tidalcycles/node_modules/osc-min" ]; then
    printf "${COLOR_PURPLE}[5]$normal TidalCycles plugin already installed, skipping ...\n"
else
    printf "${COLOR_PURPLE}[5]$normal Installing TidalCycles plugin...\n"
    /Applications/Pulsar.app/Contents/Resources/app/ppm/bin/apm install tidalcycles
    # test for successful pkg mgr install
    if [ -d "${HOME}/.pulsar/packages/tidalcycles/node_modules/osc-min" ]; then
        printf "Successful install of tidalcyles plugin in Pulsar\n"
    else
        printf "tidalcycles plugin install failed, you may need to install manually.\n"
        printf "See the Pulsar page in the Documentation:\n"
        printf "   Pulsar > Manual install of Tidal package\n"
        printf "   https://tidalcycles.org/docs/getting-started/editor/Pulsar\n"
    fi
fi

#### INSTALL SUPERCOLLIDER
if [ -d "/Applications/SuperCollider.app" ]; then
    printf "${COLOR_PURPLE}[6]$normal SuperCollider already installed, skipping...\n"
else
	printf "${COLOR_PURPLE}[6]$normal Installing SuperCollider...\n"
    scFile="/Applications/SuperCollider.app/"
    tmpDirSC=$(/usr/bin/mktemp -d /tmp/scDMG)
    scURL="https://github.com/supercollider/supercollider/releases/download/Version-3.13.0/SuperCollider-3.13.0-macOS-universal.dmg"

    curl -Lk "${scURL}" --output "${tmpDirSC}/sc3-13.dmg"
    hdiutil attach "${tmpDirSC}/sc3-13.dmg" -nobrowse -quiet -mountpoint "${tmpDirSC}"
    ditto "${tmpDirSC}/SuperCollider.app" "${scFile}"
    sleep 1
# Detach the dmg and remove the temporary mountpoint
    hdiutil detach -quiet "${tmpDirSC}"
    /bin/rm -rf "${tmpDirSC}"
fi

#### INSTALL sc3-plugins (Not sure why StkInst.scx is here. Leaving it in.)
if [[ -f "$HOME/Library/Application Support/SuperCollider/Extensions/StkInst.scx" ||
      -d "$HOME/Library/Application Support/SuperCollider/Extensions/SC3plugins" ]]; then
	printf "${COLOR_PURPLE}[7]$normal sc3-plugins already installed, skipping...\n"
else
	printf "${COLOR_PURPLE}[7]$normal Installing SuperCollider sc-3 Plugins...\n"
	curl -Lk https://github.com/supercollider/sc3-plugins/releases/download/Version-3.13.0/sc3-plugins-3.13.0-macOS.zip --output /tmp/sc3plugins.zip
	/bin/mkdir -p ~/Library/Application\ Support/SuperCollider/Extensions/SC3Plugins
	unzip -nq /tmp/sc3plugins.zip -d /tmp
    # The directory containing the SC3 plugins is located in a SC3Plugins subdirectory of the ZIP.
    # The 'mv' command creates _.* metadata files in plugin subdirectories which cause errors on SC boot;
    #   'cp' does not have this side effect.
    /bin/cp -R /tmp/sc3-plugins/SC3Plugins/* ~/Library/Application\ Support/SuperCollider/Extensions/SC3Plugins
    /bin/rm -r /tmp/sc3-plugins
	/bin/rm /tmp/sc3plugins.zip
fi

#### INSTALL SUPERDIRT
if [ -d "${HOME}/Library/Application Support/SuperCollider/downloaded-quarks/SuperDirt" ]; then
    printf "${COLOR_PURPLE}[8]$normal SuperDirt already installed, skipping..."
else
    printf "${COLOR_PURPLE}[8]$normal Installing the SuperDirt synths and samples (will take some time..)\n"
    printf 'include("SuperDirt");"SuperDirt installation complete!".postln;0.exit;' | /Applications/SuperCollider.app/Contents/MacOS/sclang
fi

printf "Tidal, SuperCollider, SuperDirt + sc-3, and Pulsar editor should now be installed!\n"
printf "Please log out and in again to complete the set up.\n"

####### Next Steps
printf "Follow these instructions to start everything up for the first time:\n"
printf "   https://tidalcycles.org/docs/getting-started/tidal_start\n"
printf "${COLOR_PURPLE}[9: Enjoy!]$normal\n\n"
exit 0
