#!/bin/bash -e

export PATH=$PATH:/usr/local/go/bin

INCOMING=$(pwd)/incoming

FOUNDARCH="armv6l"
if [ $(uname -m) = "armv6l" -o $(uname -m) = "armv7l" ]; then
    export FOUNDARCH=armv6l
elif [ $(uname -m) = "aarch64" ]; then
    export FOUNDARCH=arm64
elif [ $(uname -m) = "x86_64" ]; then
    export FOUNDARCH=amd64
fi

export go_version=$(curl -sL 'https://golang.org/VERSION?m=text' | head -1)

FILE=${go_version}.linux-${FOUNDARCH}.tar.gz

if !  ${ROOTFS_DIR}/usr/local/go/bin/go version | grep ${go_version}; then
    echo "+ Installing Golang $FILE"

    pushd /tmp
    if curl -sOL "https://go.dev/dl/${FILE}"; then
	rm -rf /usr/local/go
	ls -l ${FILE}
	tar -C /usr/local -xzf "${FILE}"
	echo "* Go is installed"
    else
	echo "@ No go lang."
    fi
    rm ${FILE}
    popd
fi

apt-get install -y pkg-config

echo "Build and install go packages"

export repo="jayofelony"
export go_pkgs="bettercap pwngrid"

for pkg in ${go_pkgs}; do
    echo " --> Checking for $pkg"
    if [ -f  ${ROOTFS_DIR}/usr/local/bin/$pkg ] ; then
	ls -l  ${ROOTFS_DIR}/usr/local/bin/$pkg
    else
	pushd ${ROOTFS_DIR}/usr/local/src

	if [ ! -d $pkg ]; then
	    if [ $pkg = "bettercap" ]; then
		echo  "Downloading from https://github.com/$pkg/$pkg"
		git clone https://github.com/$pkg/$pkg $pkg
	    else
		echo  "Downloading from https://github.com/$repo/$pkg"
		git clone https://github.com/$repo/$pkg $pkg
	    fi
	fi
	
	echo "+ Go mod tidy $pkg"
	pushd ${ROOTFS_DIR}/usr/local/src/$pkg
	go mod tidy
	echo "+ build $pkg started at $(date)"
	make -j 4

	echo "+ Installing $pkg"
	make install
	popd

	if [ -d ${INCOMING} ]; then
	    echo "# Saving binary to incoming files"
	    mkdir -p ${INCOMING}/lbin
	    cp ${ROOTFS_DIR}/usr/local/bin/$pkg ${INCOMING}/lbin/
	fi
	
	echo "- Removing $pkg source code"
	echo rm -rf $pkg
	popd
    fi
done

BETTERCAP_REPO="https://github.com/bettercap"
BETTERCAP_DIR="${ROOTFS_DIR}/usr/local/share/bettercap"
mkdir -p ${BETTERCAP_DIR}

pushd /home/pwnagotchi/git
#apt-get install -y npm

BCAP_UI_ZIPFILE="/tmp/overlay/pwnagotchi/files/bettercap-ui.zip"

# install latest bettercap/ui release
if [ ! -f "${BCAP_UI_ZIPFILE}" ]; then
    echo "+++ Downloading bettercap ui.zip"
    curl -o ${BCAP_UI_ZIPFILE} -L https://github.com/bettercap/ui/releases/download/v1.3.0/ui.zip
fi
 
if [ -f "${BCAP_UI_ZIPFILE}" ]; then
    echo "=== Unpacking bettercap ui tarball ${BCAP_UI_TARFILE}"
    pushd ${BETTERCAP_DIR}
    unzip ${BCAP_UI_ZIPFILE}
    popd
else
    echo "XXX --- > Bettercap UI is missing"
fi

for sub in caplets; do
    if [ -d "$sub" ]; then
	echo "----- Skipping bettercap $sub"
    else
	echo "+ Setting up bettercap $sub:"
	git clone ${BETTERCAP_REPO}/$sub bettercap-${sub}
	cd bettercap-${sub}
	if [[ $sub = "ui" ]]; then
	    make deps
	    make build
	    make install
	else
	    make install
	fi
	cd ..
	rm -rf bettercap-$sub
    fi
done


echo "~ Fixing caplets to not change interface, and webui always active:"
# iface is specified on command line, which is correct when pwnlib is modified
#     setting the iface in the caplet is not needed
# webui can be active during AUTO, too, with no issues
pushd ${BETTERCAP_DIR}/caplets
ls -l
(grep -v "set wifi.interface" pwnagotchi-manual.cap | tee pwnagotchi-auto.cap) || true
cp pwnagotchi-auto.cap pwnagotchi-manual.cap || true
popd # caplets


popd # BETTERCAP_DIR