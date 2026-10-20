#!/bin/bash
# Authors: James Campbell, Alex McLean, HighHarmonics
# Licence: GPLv3
# Date: September 2019
# Last Updated: Oct 2026
# Contact: james@jamescampbell.us / alex@slab.org / highharmonics@gmail.com
# What: tidalcycles installer script for OSX
#       tested on: Apple Silicon macOS 26 / 27, Intel Big Sur 11.7.1
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
#
# Change Log: Oct, 2026
#   - fixed Pulsar tidalcycles plugin install (step 5): Pulsar renamed its bundled package
#     manager from 'apm' to 'ppm', so the old apm path no longer exists and the install
#     failed with "No such file or directory". Use 'ppm' when present ('apm' kept as
#     fallback for older Pulsar), plus a git clone fallback as a last resort.
#   - fixed SuperCollider install (step 6) breaking for every re-run: the script used
#     fixed temp names (mktemp -d /tmp/scDMG) which fail with "File exists" when a
#     previous run was interrupted, leaving tmpDirSC empty. curl then tried to write
#     /sc3-13.dmg to the read-only root filesystem and everything after failed.
#     Temp dirs now have a random suffix and all download/mount/copy steps are checked.
#   - DMG installs use their own mount point (never mount over the directory holding
#     the .dmg) and verify the copied app, so a partial install is retried on re-run.
#   - updated SuperCollider and sc3-plugins to 3.14.1 (universal, native Apple Silicon)
#   - sc3-plugins: find the plugins folder case-insensitively (SC3Plugins vs SC3plugins)
#   - skip 'cabal v1-install tidal' when tidal is already installed (re-run stays fast)
#   - clear message when SuperCollider is missing instead of a raw sclang failure
#   - curl uses -f and --retry so HTTP errors are detected instead of installing garbage
#   - added --reinstall option: ignores the "already installed" checks and reinstalls
#     tidal, Pulsar, the tidalcycles plugin, SuperCollider, sc3-plugins and SuperDirt.
#     With curl:  curl ... tidal-bootstrap.command -sSf | sh -s -- --reinstall
#   - write the official SuperDirt startup file to SuperCollider's startup.scd (step 8.1):
#     it raises numBuffers/memSize and boots the server via waitForBoot, so samples load
#     after boot. Without it, Dirt-Samples (~1800 files) exceeds the SuperCollider default
#     of 1024 buffers and SuperDirt fails with "No more buffer numbers".
#     An existing startup.scd is kept as startup.scd.bak.
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

### OPTIONS
## --reinstall: reinstall every component even if it is already installed
## (run via curl as:  curl ... -sSf | sh -s -- --reinstall)
reinstall=0
for opt in "$@"; do
    case "${opt}" in
        --reinstall)
            reinstall=1
            printf '%s\n\n' "--reinstall: components that are already installed will be reinstalled."
            ;;
        *)
            printf "Unknown option: %s (only --reinstall is supported)\n" "${opt}"
            ;;
    esac
done

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
    pulsarURL="https://download.pulsar-edit.dev/?os=silicon_mac&type=mac_dmg"
else
    printf "I don't recognize your system as macOS Intel or Silicon. Aborting script.\n\n"
    exit 0
fi

### component versions
scVersion="3.14.1"
sc3PluginsVersion="3.14.1"

### TEMP DIRECTORY
## older script versions used fixed names (/tmp/PulsarDMG, /tmp/scDMG). mktemp then
## fails with "File exists" if a previous run was interrupted, which broke every
## re-run. Remove leftovers from those versions and use a random suffix instead.
/bin/rm -rf /tmp/PulsarDMG /tmp/scDMG 2>/dev/null
installTmp=$(/usr/bin/mktemp -d /tmp/tidal-bootstrap.XXXXXX)
if [ -z "${installTmp}" ] || [ ! -d "${installTmp}" ]; then
    printf "Error: could not create a temporary directory in /tmp. Aborting script.\n"
    exit 1
fi
trap '/bin/rm -rf "${installTmp}"' EXIT

#### helper: download a dmg, mount it, copy the contained app into place
## usage: install_app_from_dmg <url> <AppName.app> <destination-directory> [replace]
## with 'replace', any existing app is removed only after the dmg is downloaded
## and mounted, so a failed download never leaves the user without the app
install_app_from_dmg() {
    dmgURL="$1"
    appName="$2"
    destDir="$3"
    replace="$4"
    dmgFile="${installTmp}/${appName}.dmg"
    dmgMount="${installTmp}/mnt"

    printf "downloading %s to ${installTmp}\n" "${appName}"
    if ! curl -fL --retry 3 "${dmgURL}" --output "${dmgFile}"; then
        printf "Download failed: %s\n" "${dmgURL}"
        return 1
    fi

    /bin/mkdir -p "${dmgMount}"
    if ! hdiutil attach "${dmgFile}" -nobrowse -quiet -mountpoint "${dmgMount}"; then
        printf "Could not mount %s\n" "${dmgFile}"
        return 1
    fi

    if [ "${replace}" = "replace" ]; then
        printf "removing existing %s ...\n" "${destDir}/${appName}"
        /bin/rm -rf "${destDir}/${appName}"
    fi

    ditto "${dmgMount}/${appName}" "${destDir}/${appName}"
    dittoStatus=$?
    if [ ${dittoStatus} -ne 0 ]; then
        printf "Copying %s failed.\n" "${appName}"
        # remove the partial copy so a re-run installs it again
        /bin/rm -rf "${destDir}/${appName}"
    fi

    # unmount - retry with force, and never rm files from a still mounted image
    if ! hdiutil detach -quiet "${dmgMount}"; then
        hdiutil detach -force -quiet "${dmgMount}" || return 1
    fi
    /bin/rmdir "${dmgMount}" 2>/dev/null

    return ${dittoStatus}
}

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
## note: --reinstall does not reinstall Haskell/GHC - remove ~/.ghcup to force that
if [ -e ~/.ghcup/bin/cabal ]; then
	printf "${COLOR_PURPLE}[2]$normal Haskell found, skipping ...\n"
else
	printf "${COLOR_PURPLE}[2]$normal Installing Haskell (via 'ghcup')...\n"
    curl https://get-ghcup.haskell.org -sSf | BOOTSTRAP_HASKELL_GHC_VERSION=latest BOOTSTRAP_HASKELL_CABAL_VERSION=latest BOOTSTRAP_HASKELL_NONINTERACTIVE=1 sh 2>&1 > /tmp/ghcup-install.log
    ## test to see if cabal exists - then add the env var to shell profiles
    if [ -e "${HOME}/.ghcup/bin/cabal" ]; then
        printf "${COLOR_PURPLE}[2.1]$normal Adding ghcup initialisation to ~/.bashrc and ~/.zshrc...\n"
        for profileFile in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
            if ! grep -q '.ghcup/env' "${profileFile}"; then
                echo 'source ${HOME}/.ghcup/env' >> "${profileFile}"
            fi
        done
    else
        printf "Error: Haskell pkg mgr cabal not found in ${HOME}/.ghcup/bin. "
        printf "Check /tmp/ghcup-install.log, then re-run this script.\n"
    fi
fi

#### INSTALL TIDALCYCLES
printf "${COLOR_PURPLE}[3]$normal You should now have all the required installs for tidal...\n\n"
if [ -f "${HOME}/.ghcup/env" ]; then
    . "${HOME}/.ghcup/env"
fi
if ! command -v cabal >/dev/null 2>&1; then
    printf "Error: 'cabal' not found, skipping tidalcycles install.\n"
    printf "   Check /tmp/ghcup-install.log, then re-run this script.\n"
elif [ "${reinstall}" = "0" ] && command -v ghc-pkg >/dev/null 2>&1 && ghc-pkg list 2>/dev/null | grep -q 'tidal-'; then
    printf "tidalcycles already installed, skipping ...\n"
    printf "   (to upgrade later, run: cabal v1-install tidal)\n"
else
    printf "Installing tidalcycles haskell library (via cabal)...\n"
    cabal update
    if [ "${reinstall}" = "1" ]; then
        # cabal skips an already installed package unless --reinstall is given
        cabal v1-install --reinstall tidal
    else
        cabal v1-install tidal
    fi
fi

#### INSTALL Pulsar
pulsarApp="/Applications/Pulsar.app"
if [ "${reinstall}" = "0" ] && [ -x "${pulsarApp}/Contents/MacOS/Pulsar" ]; then
	printf "${COLOR_PURPLE}[4]$normal Pulsar already installed, skipping...\n"
else
	printf "${COLOR_PURPLE}[4]$normal Installing Pulsar...\n"
## note: zip version not available when script was completed
##     if it becomes available, this section could be reverted use zip
    if [ "${reinstall}" = "1" ]; then
        install_app_from_dmg "${pulsarURL}" "Pulsar.app" "/Applications" "replace"
    else
        install_app_from_dmg "${pulsarURL}" "Pulsar.app" "/Applications"
    fi
    if [ -x "${pulsarApp}/Contents/MacOS/Pulsar" ]; then
        # xattr command needed until pulsar provides a signed download
        xattr -cr "${pulsarApp}"
        printf "Pulsar installed.\n"
    else
        printf "Pulsar install failed, please try again or install from\n"
        printf "   https://pulsar-edit.dev/\n"
    fi
fi

#### INSTALL Pulsar plugin - this should work, but it relies on the Pulsar pkg mgr
## Pulsar (unlike Atom) ships its package manager as 'ppm'; older versions used 'apm'
pulsarPkgMgr=""
if [ -x "${pulsarApp}/Contents/Resources/app/ppm/bin/ppm" ]; then
    pulsarPkgMgr="${pulsarApp}/Contents/Resources/app/ppm/bin/ppm"
elif [ -x "${pulsarApp}/Contents/Resources/app/ppm/bin/apm" ]; then
    pulsarPkgMgr="${pulsarApp}/Contents/Resources/app/ppm/bin/apm"
fi
tidalPkgDir="${HOME}/.pulsar/packages/tidalcycles"
if [ "${reinstall}" = "0" ] && [ -d "${tidalPkgDir}/node_modules/osc-min" ]; then
    printf "${COLOR_PURPLE}[5]$normal TidalCycles plugin already installed, skipping ...\n"
elif [ -z "${pulsarPkgMgr}" ]; then
    printf "${COLOR_PURPLE}[5]$normal TidalCycles plugin install skipped: Pulsar package manager not found.\n"
    printf "   Install Pulsar, then add the 'tidalcycles' package from its Package Manager.\n"
    printf "   https://tidalcycles.org/docs/getting-started/editor/Pulsar\n"
else
    printf "${COLOR_PURPLE}[5]$normal Installing TidalCycles plugin...\n"
    if [ "${reinstall}" = "1" ] && [ -d "${tidalPkgDir}" ]; then
        printf "removing existing tidalcycles plugin ...\n"
        /bin/rm -rf "${tidalPkgDir}"
    fi
    "${pulsarPkgMgr}" install tidalcycles
    # test for successful pkg mgr install - if it failed, try a git clone install
    # (see 'Manual Installation of Tidalcycles package' on the Pulsar docs page)
    if [ ! -d "${tidalPkgDir}/node_modules/osc-min" ]; then
        printf "package manager install failed, trying git clone of pulsar-tidalcycles...\n"
        /bin/mkdir -p "${HOME}/.pulsar/packages"
        if [ ! -d "${tidalPkgDir}/.git" ]; then
            /usr/bin/git clone --depth 1 https://github.com/tidalcycles/pulsar-tidalcycles "${tidalPkgDir}"
        fi
        if [ -d "${tidalPkgDir}/.git" ]; then
            (cd "${tidalPkgDir}" && "${pulsarPkgMgr}" install)
        fi
    fi
    # test for successful pkg mgr install
    if [ -d "${tidalPkgDir}/node_modules/osc-min" ]; then
        printf "Successful install of tidalcyles plugin in Pulsar\n"
    else
        printf "tidalcycles plugin install failed, you may need to install manually.\n"
        printf "See the Pulsar page in the Documentation:\n"
        printf "   Pulsar > Manual install of Tidal package\n"
        printf "   https://tidalcycles.org/docs/getting-started/editor/Pulsar\n"
    fi
fi

#### INSTALL SUPERCOLLIDER
scApp="/Applications/SuperCollider.app"
if [ "${reinstall}" = "0" ] && [ -x "${scApp}/Contents/MacOS/sclang" ]; then
    printf "${COLOR_PURPLE}[6]$normal SuperCollider already installed, skipping...\n"
else
	printf "${COLOR_PURPLE}[6]$normal Installing SuperCollider...\n"
    scURL="https://github.com/supercollider/supercollider/releases/download/Version-${scVersion}/SuperCollider-${scVersion}-macOS-universal.dmg"
    if [ "${reinstall}" = "1" ]; then
        install_app_from_dmg "${scURL}" "SuperCollider.app" "/Applications" "replace"
    else
        install_app_from_dmg "${scURL}" "SuperCollider.app" "/Applications"
    fi
    if [ -x "${scApp}/Contents/MacOS/sclang" ]; then
        printf "SuperCollider ${scVersion} installed.\n"
    else
        printf "SuperCollider install failed, please try again or install from\n"
        printf "   https://supercollider.github.io/downloads\n"
    fi
fi

#### INSTALL sc3-plugins (Not sure why StkInst.scx is here. Leaving it in.)
scExtDir="${HOME}/Library/Application Support/SuperCollider/Extensions"
if [[ "${reinstall}" = "0" && ( -f "$scExtDir/StkInst.scx" ||
      -d "$scExtDir/SC3plugins" ||
      -d "$scExtDir/SC3Plugins" ) ]]; then
	printf "${COLOR_PURPLE}[7]$normal sc3-plugins already installed, skipping...\n"
else
	printf "${COLOR_PURPLE}[7]$normal Installing SuperCollider sc-3 Plugins...\n"
	if [ "${reinstall}" = "1" ]; then
		printf "removing existing sc3-plugins ...\n"
		/bin/rm -rf "$scExtDir/SC3plugins" "$scExtDir/SC3Plugins"
	fi
	sc3Zip="${installTmp}/sc3plugins.zip"
	sc3Tmp="${installTmp}/sc3plugins"
	if curl -fL --retry 3 "https://github.com/supercollider/sc3-plugins/releases/download/Version-${sc3PluginsVersion}/sc3-plugins-${sc3PluginsVersion}-macOS.zip" --output "${sc3Zip}"; then
		/bin/mkdir -p "${sc3Tmp}" "$scExtDir/SC3plugins"
		unzip -nq "${sc3Zip}" -d "${sc3Tmp}"
		# the plugins folder name inside the zip varies (SC3Plugins / SC3plugins);
		# -mindepth 1 stops find from matching the unzip directory itself
		sc3Src=$(find "${sc3Tmp}" -mindepth 1 -maxdepth 2 -type d -iname 'sc3plugins' | head -1)
		if [ -n "${sc3Src}" ]; then
			# The 'mv' command creates _.* metadata files in plugin subdirectories which cause errors on SC boot;
			#   'cp' does not have this side effect.
			/bin/cp -R "${sc3Src}"/* "$scExtDir/SC3plugins"
			printf "sc3-plugins ${sc3PluginsVersion} installed.\n"
		else
			printf "sc3-plugins install failed (plugin files not found in the download),\n"
			printf "   you may need to install them manually from\n"
			printf "   https://github.com/supercollider/sc3-plugins/releases\n"
		fi
	else
		printf "sc3-plugins download failed, you may need to install them manually from\n"
		printf "   https://github.com/supercollider/sc3-plugins/releases\n"
	fi
fi

#### INSTALL SUPERDIRT
scQuarksDir="${HOME}/Library/Application Support/SuperCollider/downloaded-quarks"
if [ "${reinstall}" = "0" ] && [ -d "${scQuarksDir}/SuperDirt" ]; then
    printf "${COLOR_PURPLE}[8]$normal SuperDirt already installed, skipping..."
elif [ ! -x "${scApp}/Contents/MacOS/sclang" ]; then
    printf "${COLOR_PURPLE}[8]$normal SuperDirt install skipped: SuperCollider is not installed.\n"
    printf "   Install SuperCollider, then re-run this script.\n"
else
    printf "${COLOR_PURPLE}[8]$normal Installing the SuperDirt synths and samples (will take some time..)\n"
    if [ "${reinstall}" = "1" ] && [ -d "${scQuarksDir}/SuperDirt" ]; then
        printf "removing existing SuperDirt quark (Dirt-Samples is kept, it is large) ...\n"
        /bin/rm -rf "${scQuarksDir}/SuperDirt" "${scQuarksDir}/Vowel"
    fi
    # run from a file rather than a pipe - sclang on stdin keeps re-prompting on EOF
    scScript="${installTmp}/install-superdirt.scd"
    if [ "${reinstall}" = "1" ]; then
        # sclang tracks installed quarks in its language config, so deleting the
        # folder alone is not enough - uninstall first, then include installs it again
        printf 'Quarks.uninstall("SuperDirt");Quarks.uninstall("Vowel");include("SuperDirt");"SuperDirt installation complete!".postln;0.exit;' > "${scScript}"
    else
        printf 'include("SuperDirt");"SuperDirt installation complete!".postln;0.exit;' > "${scScript}"
    fi
    "${scApp}/Contents/MacOS/sclang" "${scScript}"
fi

#### SUPERCOLLIDER startup.scd
## write the official SuperDirt startup file: it raises numBuffers/memSize and
## boots the server via waitForBoot, so samples are loaded AFTER boot (with the
## new options in effect) instead of against a stale allocator.
scStartup="${HOME}/Library/Application Support/SuperCollider/startup.scd"
if [ ! -x "${scApp}/Contents/MacOS/sclang" ]; then
    : # SuperCollider not installed, nothing to configure
elif [ -f "${scStartup}" ] && grep -q 'loadSoundFiles' "${scStartup}"; then
    printf "${COLOR_PURPLE}[8.1]$normal SuperCollider startup.scd already configured, skipping...\n"
else
    printf "${COLOR_PURPLE}[8.1]$normal Writing SuperDirt startup file to startup.scd ...\n"
    /bin/mkdir -p "${HOME}/Library/Application Support/SuperCollider"
    # keep any existing startup file rather than overwriting it
    if [ -f "${scStartup}" ]; then
        /bin/cp "${scStartup}" "${scStartup}.bak"
        printf "   (existing startup.scd saved as startup.scd.bak)\n"
    fi
    cat > "${scStartup}" << 'EOF'
/*
This is an example startup file.
If you want to modify it, best copy it elsewhere to keep the git repository clean.

You can then load it by calling
"path/to/my/superdirt_startup.scd".load
from the supercollider startup file

The supercollider startup file is to be found in
Platform.userAppSupportDir +/+ "startup.scd",
or via the menu File > Open startup file
*/


(
s.reboot { // server options are only updated on reboot
    // configure the sound server: here you could add hardware specific options
    // see http://doc.sccode.org/Classes/ServerOptions.html
    s.options.numBuffers = 1024 * 256; // increase this if you need to load more samples
    s.options.memSize = 8192 * 32; // increase this if you get "alloc failed" messages
    s.options.numWireBufs = 2048; // increase this if you get "exceeded number of interconnect buffers" messages
    s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
    s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
    s.options.numInputBusChannels = 2; // set this to your hardware output channel size, if necessary
    // boot the server and start SuperDirt
    s.waitForBoot {
        ~dirt.stop; // stop any old ones, avoid duplicate dirt (if it is nil, this won't do anything)
        ~dirt = SuperDirt(2, s); // two output channels, increase if you want to pan across more channels
        ~dirt.loadSoundFiles;   // load samples (path containing a wildcard can be passed in)
        // for example: ~dirt.loadSoundFiles("/Users/myUserName/Dirt/samples/*");
        // s.sync; // optionally: wait for samples to be read
        ~dirt.start(57120, 0 ! 12);   // start listening on port 57120, create two busses each sending audio to channel 0
        SuperDirt.default = ~dirt; // make this instance available in sclang (optional)

        // optional, needed for convenient access from sclang:
        (
            ~d1 = ~dirt.orbits[0]; ~d2 = ~dirt.orbits[1]; ~d3 = ~dirt.orbits[2];
            ~d4 = ~dirt.orbits[3]; ~d5 = ~dirt.orbits[4]; ~d6 = ~dirt.orbits[5];
            ~d7 = ~dirt.orbits[6]; ~d8 = ~dirt.orbits[7]; ~d9 = ~dirt.orbits[8];
            ~d10 = ~dirt.orbits[9]; ~d11 = ~dirt.orbits[10]; ~d12 = ~dirt.orbits[11];
        );

        // directly below here, in your own copy of this file, you could add further code that you want to call on startup
        // this makes sure the server and ~dirt are running
        // you can keep this separate and make it easier to switch between setups
        // by using "path/to/my/file.scd".load and if necessary commenting out different load statements
        // ...

    };

    s.latency = 0.3; // increase this if you get "late" messages


};
)
EOF
fi

printf "Tidal, SuperCollider, SuperDirt + sc-3, and Pulsar editor should now be installed!\n"
printf "Please log out and in again to complete the set up.\n"

####### Next Steps
printf "Follow these instructions to start everything up for the first time:\n"
printf "   https://tidalcycles.org/docs/getting-started/tidal_start\n"
printf "${COLOR_PURPLE}[9: Enjoy!]$normal\n\n"
exit 0
