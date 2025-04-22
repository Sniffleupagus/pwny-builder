#!/bin/bash -e

# install nexmon
NEXMON_REPO=https://github.com/Sniffleupagus/nexmon.git

NEXMON_DKMS_REPO=https://gitlab.com/nursejackass/brcmfmac-nexmon-dkms.git

# raspberry pi defaults
NEXMON_PATCHES="bcm43430a1/7_45_41_46 bcm43455c0/7_45_206 bcm43436b0/9_88_4_65"

if [ ${BOARD} == "bananapim4zero" ]; then
    NEXMON_PATCHES="bcm43455c0/7_45_206"
fi
cd /usr/local/src

BUILT_ONE=false

NEXMON_DKMS_ROOT="/usr/src/brcmfmac-nexmon-dkms"
pushd /usr/src
if [ ! -d brcmfmac-nexmon-dkms ]; then
    git clone ${NEXMON_DKMS_REPO}
    ln -s brcmfmac-nexmon-dkms brcmfmac-nexmon-dkms-6.6
fi
pushd ${NEXMON_DKMS_ROOT}

# install dkms alone, without installing host-OS linux headers
apt-get -yq install --no-install-recommends dkms

# build DKMS kernel modules
ls -l ${ROOTFS_DIR}/lib/modules
for m in $(cd ${ROOTFS_DIR}/lib/modules ; ls); do
    if [ -d ${ROOTFDS_DIR}/lib/modules/$m/build ]; then
	mod=$m
	echo
	echo ">>>---> building DKMS Nexmon module for $mod"

	export QEMU_UNAME=$mod
	export PLATFORMUNAME=$mod
	export KERNELRELEASE=$mod
	uname -a

	export KERNEL=$(echo $mod | cut -d . -f -2)
	MOD_DEST=${ROOTFS_DIR}/lib/modules/${mod}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac

	echo "+ Building DKMS nexmon module for ${mod}"
	KERNELRELEASE=$mod make clean || true
	#make
	#make install

	dkms add     -m brcmfmac-nexmon-dkms -v 6.6 -k $mod
	dkms build   -m brcmfmac-nexmon-dkms -v 6.6 -k $mod || cat /var/lib/dkms/brcmfmac-nexmon-dkms/6.6/build/make.log
	dkms install -m brcmfmac-nexmon-dkms -v 6.6 -k $mod --force
    fi
done
popd

echo "+ Holding firmware-brcm80211 to avoid updating and overwriting nexmon custom firmware"
apt-mark hold firmware-brcm80211

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
	pushd nexmon
    else
	echo "=== cloning nexmon repository $NEXMON_REPO"
	echo "in 10" ; sleep 10
	git clone --depth=1 $NEXMON_REPO
	pushd nexmon
    fi
else
    pushd nexmon
fi

echo Disable Statistics
touch DISABLE_STATISTICS

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

ls -l /usr/bin/nexutl || true

# build Nexmon patched firmware, using last kernel version "mod"
echo "* --> Building patched firmware"
export KERNEL_REV=$(echo $mod | sed 's/\([0-9]\+\.[0-9]\+\)\..*/\1/')
for p in $NEXMON_PATCHES; do
    pushd patches/$p/nexmon

    sed -i -e 's#^KERNEL_VERSION = .*$#KERNEL_VERSION = \$(if $(KERNEL_REV),\$(KERNEL_REV),\$(shell uname -r | sed "s/\\([0-9]\\+\\.[0-9]\\+\\)\\..*/\\1/"))#' Makefile
    
    # instead of building the module, let it find the local file
    # actual module is built with dkms above
    echo "    ===---> make clean $p"
    KERNEL_REV=${KERNEL_REV} make clean || true
    RAMFILE=$(cat ${NEXMON_ROOT}/firmwares/$p/definitions.mk | grep RAM_FILE | cut -d = -f 2)
    echo "    ===---> patch firmware $p: ${RAMFILE}"
    make ${RAMFILE}
    echo "    ===+++> install patched firmware $p/${RAMFILE}"
    # use invalid kernel number so install-firmware
    # skips module unloading and loading

    # patch the Makefile to not build brcmfmac.ko, just the firmware
    sed -i -e 's/^install-firmware: $(RAM_FILE) brcmfmac.ko/install-firmware: $(RAMFILE)/' Makefile
    
    QEMU_UNAME=4.20.69 make install-firmware || true
    BUILT_ONE=true
    popd
done

popd
rm -r nexmon

# system specific configuration
if [ ${BOARD} == "bananapim4zero" ]; then
    pushd /usr/lib/firmware
    if [ ! -f  updates/brcm/cyfmac43455-sdio.bin.ORIG ]; then
	echo "Saving backup of original cyfmac43455 firmware"
	mv updates/brcm/cyfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin.ORIG
    fi
    echo "Copying nexmon 43455 firmware to updates/brcm/cyfmac43455-sdio.bin"
    cp -f brcm/brcmfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin
    mkdir -p /tmp/pwny_parts/usr/bin
    cp -f /usr/bin/nexutil /tmp/pwny_parts/usr/bin
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
    tar --ignore-failed-read -cvvzf ${INCOMING}/nexmon_backup.tar.gz \
	lib/modules/*/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac \
	lib/firmware/brcm/brcmfmac43{430,455,436,436s}-sdio.bin usr/bin/nexutil || true
    popd
fi

apt -y remove binutils-arm-none-eabi gcc-arm-none-eabi
