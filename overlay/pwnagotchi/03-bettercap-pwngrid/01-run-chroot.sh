#!/bin/bash -e

export PATH=$PATH:/usr/local/go/bin

INCOMING=$(pwd)/incoming
echo "Incoming is ${INCOMING}"

CheckInstallGo () {
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

    if !  /usr/local/go/bin/go version | grep ${go_version}; then
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
}

export repo="jayofelony"

export go_pkgs="bettercap pwngrid"

for pkg in ${go_pkgs}; do
    echo " --> Checking for $pkg"
    if [ -f  /usr/local/bin/$pkg ] ; then
	ls -l  /usr/local/bin/$pkg
    elif [ -f ${PWNY_DIR}/files/${BOARD}/usr/local/bin/$pkg ]; then
	echo "+-> Installing precompiled $pkg"
	cp -rp ${PWNY_DIR}/files/${BOARD}/usr/local/bin/$pkg /usr/local/bin
    else
	echo "Building $pkg"
	CheckInstallGo
	pushd /usr/local/src

	if [ ! -d $pkg ]; then
	    if [ $pkg = "bettercap" ]; then
		echo  "Downloading from https://github.com/$pkg/$pkg"
		git clone --branch patch-1 https://github.com/Sniffleupagus/$pkg $pkg
	    else
		echo  "Downloading from https://github.com/$repo/$pkg"
		git clone https://github.com/$repo/$pkg $pkg
	    fi
	fi
	figlet $pkg || true
	echo "+ Go mod tidy $pkg"
	pushd /usr/local/src/$pkg
	go mod tidy
	echo "+ build $pkg started at $(date)"
	make

	echo "+ Installing $pkg"
	make install
	popd

	if [ -f /usr/local/bin/$pkg ]; then
	    echo "---> backing up $pkg for next build"
	    mkdir -p /tmp/pwny_parts/usr/local/bin
	    cp /usr/local/bin/$pkg /tmp/pwny_parts/usr/local/bin
	fi

	if [ -d ${INCOMING} ]; then
	    echo "# Saving binary to incoming files"
	    mkdir -p ${INCOMING}/lbin
	    cp /usr/local/bin/$pkg ${INCOMING}/lbin/
	fi
	
	echo "- Removing $pkg source code"
	echo rm -rf $pkg
	popd
    fi
done

BETTERCAP_REPO="https://github.com/bettercap"
BETTERCAP_DIR="/usr/local/share/bettercap"
mkdir -p ${BETTERCAP_DIR}

echo "Bettercap: $(/usr/local/bin/bettercap -version || true)"
echo "Pwngrid: $(/usr/local/bin/pwngrid -version || true)"

pushd /home/pwnagotchi/git

BCAP_UI_ZIPFILE="${PWNY_DIR}/files/bettercap-ui.zip"

# install latest bettercap/ui release
 
if [ ! -d "${BETTERCAP_DIR}/ui" ]; then
    if [ -f "${BCAP_UI_ZIPFILE}" ]; then
	echo "=== Unpacking bettercap ui tarball ${BCAP_UI_TARFILE}"
	pushd ${BETTERCAP_DIR}
	unzip -q ${BCAP_UI_ZIPFILE}
	popd
    else
	echo "+++ Downloading bettercap ui.zip"
	pushd ${BETTERCAP_DIR}
	curl -OL https://github.com/bettercap/ui/releases/download/v1.3.0/ui.zip
	ls -l
	unzip -q ui.zip && rm ui.zip
    fi
fi


# install caplets
# iface is specified on command line, which is correct when pwnlib is modified
#     setting the iface in the caplet is not needed
# webui can be active during AUTO, too, with no issues
echo "+++ Installing caplets"
pushd /tmp
git clone https://github.com/bettercap/caplets.git
cd caplets
sudo make install
popd
pushd ${BETTERCAP_DIR}
#/usr/local/bin/bettercap -caplets-path ${BETTERCAP_DIR} -eval "caplets.update -iface lo ; quit" || true
cd caplets
if [[ -f pwnagotchi-manual.cap ]]; then
    echo "~ Fixing caplets to not change interface, and webui always active:"
    (grep -v "set wifi.interface" pwnagotchi-manual.cap | tee pwnagotchi-auto.cap) || true

    cat >>pwnagotchi-auto.cap <<EOF

set wifi.handshakes.file /root/handshakes/
set wifi.handshakes.aggregate false
EOF

    cp pwnagotchi-auto.cap pwnagotchi-manual.cap || true
    ls -l pwn*
else
    echo "No caplet to fix"
    ls -l
fi
popd # caplets


popd # BETTERCAP_DIR
