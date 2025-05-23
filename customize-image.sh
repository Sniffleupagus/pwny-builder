#!/bin/bash -e

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

export RELEASE=$1
export LINUXFAMILY=$2
export BOARD=$3
export BUILD_DESKTOP=$4


PWNLOGFILE=$(mktemp /tmp/pwnagotchi.XXXXXX)


PWNYPACKAGES="aircrack-ng ansible autoconf bc bison bluez build-essential curl dkms dphys-swapfile espeak-ng evtest fbi flex fonts-dejavu fonts-dejavu-core fonts-dejavu-extra fonts-freefont-ttf g++ gawk gcc-arm-none-eabi git libatlas-base-dev libblas-dev libbz2-dev libc-ares-dev libc6-dev libcpuinfo-dev libdbus-1-dev libdbus-glib-1-dev libeigen3-dev libelf-dev libffi-dev libfl-dev libfuse-dev libgdbm-dev libgl1-mesa-glx libgmp3-dev libgstreamer1.0-0 libhdf5-dev liblapack-dev libncursesw5-dev libnetfilter-queue-dev libopenblas-dev libopenjp2-7 libopenmpi-dev libopenmpi3 libpcap-dev libprotobuf-dev libsleef-dev libsqlite3-dev libssl-dev libtool libts-bin libusb-1.0-0-dev lsof make python3-flask python3-flask-cors python3-flaskext.wtf python3-pil python3-pip python3-protobuf python3-smbus qpdf rsync screen tcpdump texinfo time tk-dev unzip vim wget wl xxd zlib1g-dev libavcodec58 libavformat58 libswscale5 libtiff5 spi-tools python3-requests python3-scapy python3-tweepy python3-pandas python3-oauthlib python3-sympy python3-fsspec python3-networkx"

PWNY_PIPPKGS="pycryptodome"

InstallGoGit () {
    pkg=$1
    repo=$2

    cd /usr/local/src
    git clone https://github.com/$repo/$pkg
    cd $pkg
    go mod tidy
    make
    make install
    cd ..
    rm -rf $pkg
}

InstallGo () {
    version=${1:1.21.5}
    arch=${2:armv61}

    if [ $(uname -m) = "armv6l" or $(uname -m) = "armv7l" ]; then
	export GOARCH=armv6l
    elif [ $(uname -m) = "aarch64" ]; then
	export GOARCH=arm64
    fi
    
    cd /tmp
    curl -OL "https://go.dev/dl/go${version}.linux-${GOARCH}.tar.gz"
    tar -C /usr/local -xzf "go${version}.linux-${GOARCH}.tar.gz"
}

NTFY_SERVER=${NTFY_SERVER:-"ntfy.sh"}
NTFY_TOPIC=${NTFY_TOPIC:-""}

function ntfy_send() {
    title=${1:-''}
    priority=${2:-'default'}
    tags=${3:-'warning'}
    markdown=${4:-''}

    if [ -n "${NTFY_TOPIC}" ]; then
	cat | curl -s -H "t:${title}"  -H "p:${priority}" -H "ta: ${tags}" -d @-  ${NTFY_SERVER}/${NTFY_TOPIC}
    else
	cat >/dev/null
    fi
}

Main() {
	case $RELEASE in
		stretch)
			# your code here
			;;
		buster)
			# your code here
			;;
		bullseye)
			# your code here
			;;
		bionic)
			# your code here
			;;
		focal)
			# your code here
			;;
	esac

	echo
	echo "!!! Beginning Pwnagotchi Build !!!"
	echo "Release: $1, Linux $2, Board $3, Desktop $4"
	export RELEASE=$1
	export BOARD=$3
	# this is in the chroot, so build the pwny
	echo "# arguments called with ---->  ${@}     "
	echo "# path to me --------------->  ${0}     "
	echo "# parent path -------------->  ${0%/*}  "
	echo "# my name ------------------>  ${0##*/} "
	echo "Building in $(pwd)"
	#ls -lR ${0%/*}
	cd ${0%/*}
	#ls -l /tmp/overlay/pwnagotchi/
	export PWNY_DIR=/tmp/overlay/pwnagotchi
	export PI_GEN=armbian-build
	export OVERLAY_DIR=/tmp/overlay/pwnagotchi
	export PWNY_BUILD_ARTIFACTS=${PWNY_BUILD_ARTIFACTS:-"/root/artifacts/armbian-build/$3/$1"}
	export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"armbian-build/$3/$1"}
	ln -s /tmp/overlay /root/overlay   # make /tmp/overlay/pwnagotchi/common.sh accessible
	printenv

	echo "===== apt update ====="
	apt-get -yq --allow-releaseinfo-change update
	echo "===== apt upgrade ====="
	if [ "${DO_APT_UPGRADE:-'YES'}" == "YES" ]; then
	    echo "Apt uprade"
	    apt-get -yq upgrade $(cat ${p})
	fi

	echo "===== pwnagotchi packages ====="
	pushd /tmp/overlay/pwnagotchi
	for p in $(find . -name '[0-9][0-9]-packages' | sort -V ); do
 	    echo "=---> $p" | tee -a ${PWNLOGFILE}
	    apt-get -yqq install $(cat ${p})
	done

	echo "===== pwnagotchi scripts ====="
	# all of it happens in chroot, so just execute all of the scripts in order and hope for the best
	for s in $(find . -name '[0-9][0-9]-*.sh' | sort -V ); do
	    echo "=---> $s" | tee -a ${PWNLOGFILE}
	    pushd $(dirname $s)
	    bash -e $(basename $s)
	    popd
	done
	popd
	echo "----- End of Pwnagotchi Build Scripts"
} # Main


Main "$@"
