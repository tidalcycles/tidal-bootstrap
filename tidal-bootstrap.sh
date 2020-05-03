#!/bin/bash
# Authors: James Campbell, Alex McLean
# Licence: GPLv3
# Date: September 2019
# Last Updated: October 2019
# Contact: james@jamescampbell.us / alex@slab.org
# What: tidalcycles installer script for OSX and Linux

#### COLORS
COLOR_PURPLE='\033[0;35m'
normal='\033[0m'

get_distro_alias() {
    distro_name=$1
    distro_alias=unknown

    case "${distro_name}" in
        "Debian"|"Debian GNU/Linux"|"debian")
            distro_alias=debian
            ;;
        "Ubuntu"|"ubuntu")
            distro_alias=ubuntu
            ;;
        "Exherbo"|"exherbo")
            distro_alias=exherbo
            ;;
        "Fedora"|"fedora")
            distro_alias=fedora
            ;;
        "CentOS Linux"|"CentOS"|"centos"|"Red Hat Enterprise Linux"*)
            distro_alias=centos
            ;;
        "Alpine Linux"|"Alpine")
            distro_alias=alpine
            ;;
        "Linux Mint"|"LinuxMint")
            distro_alias=mint
            ;;
        "Amazon Linux AMI")
            distro_alias=amazonlinux
            ;;
        "AIX")
            distro_alias=aix
            ;;
        "FreeBSD")
            distro_alias=freebsd
            ;;
        "Darwin")
            distro_alias=darwin
            ;;
    esac

    printf "%s" "${distro_alias}"

    unset distro_name distro_alias
}

get_distro_name() {
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        # shellcheck disable=SC1091
        . /etc/os-release
        printf "%s" "$NAME"
    elif command_exists lsb_release ; then
        # linuxbase.org
        printf "%s" "$(lsb_release -si)"
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        # shellcheck disable=SC1091
        . /etc/lsb-release
        printf "%s" "$DISTRIB_ID"
    elif [ -f /etc/redhat-release ]; then
        case "$(cat /etc/redhat-release)" in
        # Older CentOS releases didn't have a /etc/centos-release file
        "CentOS release "*)
            printf "CentOS"
            ;;
        "CentOS Linux release "*)
            printf "CentOS Linux"
            ;;
        "Fedora release "*)
            printf "Fedora"
            ;;
        # Fallback to uname
        *)
            printf "%s" "$(uname -s)"
            ;;
        esac
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        printf "Debian"
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        printf "%s" "$(uname -s)"
    fi
}

get_distro_ver() {
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        # shellcheck disable=SC1091
        . /etc/os-release
        printf "%s" "$VERSION_ID"
    elif command_exists lsb_release ; then
        # linuxbase.org
        printf "%s" "$(lsb_release -sr)"
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        # shellcheck disable=SC1091
        . /etc/lsb-release
        printf "%s" "$DISTRIB_RELEASE"
    elif [ -f /etc/redhat-release ]; then
        case "$(cat /etc/redhat-release)" in
        # NB: Older CentOS releases didn't have a /etc/centos-release file
        "CentOS release "*|"Fedora release "*)
            printf "%s" "$(awk 'NR==1 { split($3, a, "."); print a[1] }' /etc/redhat-release)"
            ;;
        "CentOS Linux release "*)
            printf "%s" "$(awk 'NR==1 { split($4, a, "."); print a[1] }' /etc/redhat-release)"
            ;;
        # Fallback to uname
        *)
            printf "%s" "$(uname -r)"
            ;;
        esac
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        printf "%s" "$(cat /etc/debian_version)"
    else
        case "$(uname -s)" in
        AIX)
            printf "%s" "$(uname -v)"
            ;;
        FreeBSD)
            # we only care about the major numeric version part left of
            # the '.' in "11.2-RELEASE".
            printf "%s" "$(uname -r | cut -d . -f 1)"
            ;;
        *)
            # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
            printf "%s" "$(uname -r)"
        esac
    fi
}

get_arch() {
    myarch=$(uname -m)

    case "${myarch}" in
    x86_64|amd64)
        printf "x86_64"  # or AMD64 or Intel64 or whatever
        ;;
    i*86)
        printf "i386"  # or IA32 or Intel32 or whatever
        ;;
    *)
        case "$(uname -s)" in
        AIX)
            case "$(uname -p)" in
            powerpc)
                printf "powerpc"
                ;;
            *)
                die "Cannot figure out architecture on AIX (was: ${myarch})"
                ;;
            esac
            ;;
        *)
            die "Cannot figure out architecture (was: ${myarch})"
            ;;
        esac
    esac

    unset myarch
}


echo "Detected system information:"
echo "  Architecture:   $(get_arch)"
echo "  Distribution:   $(get_distro_name)"
echo "  Distro alias:   $(get_distro_alias "$(get_distro_name)")"
echo "  Distro version: $(get_distro_ver)"

mydistro=$(get_distro_alias "$(get_distro_name)")

#### CHECK FOR NIX
if [ -e /home/alex/.nix-profile/etc/profile.d/nix.sh ]; then
    printf "$COLOR_PURPLE[2]$normal Nix found...\n"
    . /home/alex/.nix-profile/etc/profile.d/nix.sh
else
    printf "$COLOR_PURPLE[2]$normal Installing Nix...\n"
    curl -L https://nixos.org/nix/install | sh
fi

#### INSTALL TIDALCYCLES
printf "$COLOR_PURPLE[3]$normal Congratulations, you have all the pre-reqs...\n"
echo "Installing tidalcycles haskell library (via nix)..."
echo ""
nix-env -iA nixpkgs.haskellPackages.tidal_1_4_9

#### INSTALL
printf "$COLOR_PURPLE[4]$normal Installing Atom...\n"
nix-env -i atom

printf "$COLOR_PURPLE[6]$normal Installing atom TidalCycles plugin...\n"
nix-shell -p atom --run "apm install tidalcycles"

printf "$COLOR_PURPLE[6]$normal Attempting to configure plugin to use nix...\n"
if [ -e ~/.atom/config.cson ] ; then
   if grep -q 'interpreter: "nix"' ~/.atom/config.cson; then
       printf "Atom already configured.\n"
   else
       sed -i.bak  's/^"\*"$/"*"\n  tidalcycles:\n    interpreter: "nix"/' ~/.atom/config.cson
   fi
else
    echo "\"*\"
  tidalcycles:
    interpreter: \"nix\"
" > ~/.atom/config.cson
fi

#### INSTALL SUPERCOLLIDER
if test "${mydistro}" = "darwin"; then
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
	curl -Lk https://github.com/supercollider/sc3-plugins/releases/download/Version-3.10.0/sc3-plugins-3.10.0-macOS-signed.zip --output /tmp/sc3plugins.zip
	mkdir -p ~/Library/Application\ Support/SuperCollider/Extensions/
	unzip -q /tmp/sc3plugins.zip -d ~/Library/Application\ Support/SuperCollider/Extensions/
	rm /tmp/sc3plugins.zip
    fi
else
    if command -v scide 2>/dev/null; then
	printf "$COLOR_PURPLE[7]$normal SuperCollider already installed, skipping...\n"
    else
	printf "$COLOR_PURPLE[7]$normal Downloading, compiling and installing SuperCollider and sc3plugins...\n"
	mkdir ~/tidal-tmp
	cd ~/tidal-tmp
	git clone https://github.com/lvm/build-supercollider
	cd build-supercollider
	./build-supercollider.sh
	./build-sc3-plugins.sh
    fi

    printf "$COLOR_PURPLE[7.1]$normal Adding user to the 'audio' group.\n"
    sudo adduser $USER audio
fi


#### INSTALL SUPERDIRT
echo "$COLOR_PURPLE[9]$normal Installing the SuperDirt synths and samples (will take some time..)"
if test "${mydistro}" = "darwin"; then
    echo 'include("SuperDirt");"SuperDirt installation complete!".postln;0.exit;' | /Applications/SuperCollider.app/Contents/MacOS/sclang
else
    echo 'include("SuperDirt");"SuperDirt installation complete!".postln;0.exit;' | sclang
fi

echo "Tidal and SuperDirt should now be installed!\n\n"

echo "Please log out and in again to complete the set up.\n\n"

echo "You can then follow the instructions here to start everything up for the first time:"
echo "  https://tidalcycles.org/index.php/Start_tidalcycles_and_superdirt_for_the_first_time"
echo "Enjoy!"
exit 0
