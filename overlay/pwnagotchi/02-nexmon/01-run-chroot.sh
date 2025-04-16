#!/bin/bash -e

# install nexmon
NEXMON_REPO=https://github.com/DrSchottky/nexmon.git

NEXMON_DKMS_REPO=https://gitlab.com/nursejackass/brcmfmac-nexmon-dkms.git

# raspberry pi defaults
NEXMON_PATCHES="bcm43430a1/7_45_41_46 bcm43455c0/7_45_206 bcm43436b0/9_88_4_65"

if [ ${BOARD} == "bananapim4zero" ]; then
    NEXMON_PATCHES="bcm43455c0/7_45_206"
fi

PHOME="/home/pwnagotchi"

cd /usr/local/src

mkdir -p ${PHOME}/git
pushd ${PHOME}/git

BUILT_ONE=false

NEXMON_DKMS_ROOT="/usr/src/brcmfmac-nexmon-dkms"
pushd /usr/src
if [ ! -d brcmfmac-nexmon-dkms ]; then
    git clone ${NEXMON_DKMS_REPO}
    ln -s brcmfmac-nexmon-dkms brcmfmac-nexmon-dkms-6.6
fi
pushd ${NEXMON_DKMS_ROOT}

if [ -f "/boot/armbianEnv.txt" -o -f "/boot/extlinux/extlinux.conf" ]; then
    echo "Disabling -DDEBUG flag on Armbian"
    sed -i '/-DDEBUG$/s/-DDEBUG/\#-DDEBUG/' Makefile
fi

# build DKMS kernel modules
for m in $(cd /lib/modules ; ls); do
    if [ -d /lib/modules/$m/build ]; then
	mod=$m
	echo
	echo ">>>---> building DKMS Nexmon module for $mod"
	curl -s -d "build dkms nexmon $mod" ntfy.sh/pwny_builder

	export QEMU_UNAME=$mod
	export PLATFORMUNAME=$mod
	uname -a

	export KERNEL=$(echo $mod | cut -d . -f -2)
	MOD_DEST=/lib/modules/${mod}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac

	echo "+ Building DKMS nexmon module for ${mod}"
	make clean || true
	#make
	#make install

	dkms add     -m brcmfmac-nexmon-dkms -v 6.6 -k $mod
	dkms build   -m brcmfmac-nexmon-dkms -v 6.6 -k $mod
	dkms install -m brcmfmac-nexmon-dkms -v 6.6 -k $mod --force
    fi
done
popd

# download or unpack nexmon
NEXMON_TARFILE="/tmp/overlay/pwnagotchi/files/nexmon-dev.zip"
if [ ! -d nexmon ]; then
    if [ -f "${NEXMON_TARFILE}" ]; then
	echo
	echo "=== Unpacking nexmon tarball ${NEXMON_TARFILE}"
	unzip -q ${NEXMON_TARFILE}
	if [ -d nexmon-dev ]; then
	    mv nexmon-dev nexmon
	fi
    else
	echo "=== cloning nexmon repository $NEXMON_REPO"
	git clone --depth=1 $NEXMON_REPO
    fi
    cd nexmon
else
    cd nexmon
fi

if [ -f "/boot/armbianEnv.txt" ]; then
    # -DDEBUG in the driver does not compile on armbian
    echo "* --> Removing -DDEBUG from driver Makefile"
    pushd patches/driver/brcmfmac_6.6.y-nexmon
    sed -i '/-DDEBUG$/d' Makefile
    sed -i 's/include \\$/include/' Makefile
    popd
fi

echo "* Setting up build environment"
source setup_env.sh
make

# build utility
if [ ! -f /usr/bin/nexutil ]; then
    echo "+ Building nexutil"
    pushd utilities/nexutil
    make
    make install
    BUILT_ONE=true
    popd
fi

# build Nexmon patched firmware, using last kernel version "mod"
echo "* --> Building patched firmware"
for p in $NEXMON_PATCHES; do
    pushd patches/$p/nexmon
    echo "    ===---> make clean $p"
    make clean || true
    RAMFILE=$(cat ${NEXMON_ROOT}/firmwares/$p/definitions.mk | grep RAM_FILE | cut -d = -f 2)
    echo "    ===---> patch firmware $p: ${RAMFILE}"
    make ${RAMFILE}
    echo "    ===+++> install patched firmware $p/${RAMFILE}"
    # use invalid kernel number so install-firmware
    # skips module unloading and loading
    QEMU_UNAME=4.20.69 make install-firmware || true
    BUILT_ONE=true
    popd
done

curl -s -d "=== nexmon build complete" ntfy.sh/pwny_builder

# system specific configuration
if [ ${BOARD} == "bananapim4zero" ]; then
    pushd /usr/lib/firmware
    if [ ! -f  updates/brcm/cyfmac43455-sdio.bin.ORIG ]; then
	echo "Saving backup of original cyfmac43455 firmware"
	mv updates/brcm/cyfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin.ORIG
    fi
    echo "Copying nexmon 43455 firmware to updates/brcm/cyfmac43455-sdio.bin"
    cp -f brcm/brcmfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin
    mkdir -p /tmp/pwny_parts/lib/firmware/brcm
    mkdir -p /tmp/pwny_parts/lib/firmware/updates/brcm
    cp -f brcm/brcmfmac43455-sdio.bin /tmp/pwny_parts/lib/firmware/brcm
    cp -f updates/brcm/brcmfmac43455-sdio.bin /tmp/pwny_parts/lib/firmware/updates/brcm
    cp -f updates/brcm/cyfmac43455-sdio.bin /tmp/pwny_parts/lib/firmware/updates/brcm/cyfmac43455-sdio.bin
    echo "Finished building nexmon"
else
    # raspberry pi
    if [ ! -L /usr/lib/firmware/brcm/brcmfmac43436s-sdio.bin ]; then
	echo Linking 43430 firmware to 43436s for pizero2w with 43430 chip
	ln -sf /usr/lib/firmware/brcm/brcmfmac43430-sdio.bin /usr/lib/firmware/brcm/brcmfmac43436s-sdio.bin
    else
	echo -n Link 43430->43436s exists
	ls -l /usr/lib/firmware/brcm/brcmfmac43436s-sdio.bin
    fi
fi

if ${BUILT_ONE} ; then
    echo " *> Saving all nexmon products"
    INCOMING=/tmp/pwny_parts
    mkdir -p ${INCOMING}
    pushd /
    tar -cvvzf ${INCOMING}/nexmon_backup.tar.gz \
	lib/modules/*/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac \
	lib/firmware/brcm/brcmfmac43{430,455,436,436s}-sdio.bin usr/bin/nexutil
    popd
    curl -s -d "Pwnagotchi built nexmon" ntfy.sh/pwny_builder
fi

