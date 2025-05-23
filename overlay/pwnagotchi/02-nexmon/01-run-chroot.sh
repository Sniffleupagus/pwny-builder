#!/bin/bash -e

. /root/overlay/pwnagotchi/common.sh

# install nexmon
NEXMON_REPO=https://github.com/Sniffleupagus/nexmon.git

NEXMON_DKMS_REPO=https://gitlab.com/nursejackass/brcmfmac-nexmon-dkms.git

# raspberry pi defaults
NEXMON_PATCHES=${NEXMON_PATCHES:-"bcm43430a1/7_45_41_46 bcm43455c0/7_45_206 bcm43436b0/9_88_4_65"}

if [ "${BOARD}" == "bananapim4zero" ]; then
    NEXMON_PATCHES="bcm43455c0/7_45_206"
fi

echo ${PWNY_BUILD_ARTIFACTS}

###########################

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
echo "/lib/modules"
uname -a
ls -l /lib/modules || true
echo "ROOTFS_DIR = ${ROOTFS_DIR}"

if [ -d "${ROOTFS_DIR}" ]; then
    KERNELS=${ROOTFS_DIR}/lib/modules
else
    KERNELS=/lib/modules
fi
ls -l ${KERNELS}

figlet nexmon
for m in $(cd ${KERNELS} ; ls); do
    if [ -d ${KERNELS}/$m/build ]; then
	mod=$m
	export QEMU_UNAME=$mod
	export PLATFORMUNAME=$mod
	export KERNELRELEASE=$mod

	uname -a

	export KERNEL=$(echo $mod | cut -d . -f -2)
	MOD_DEST=${KERNELS}/${mod}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac

	if ! dkms status -m brcmfmac-nexmon-dkms -v 6.6 -k $mod | grep installed; then
	    #if [ ! -d /usr/src/brcmfmac-nexmon-dkms-6.6 ]; then # add happens automatic with build
	    #    dkms add -m brcmfmac-nexmon-dkms -v 6.6 -k $mod
	    #fi
	    echo "# Building brcmfmac-nexmon-dkms module"
	    
	    dkms build   -m brcmfmac-nexmon-dkms -v 6.6 -k $mod
	    echo "+ Installing brcmfmac-nexmon-dkms"
	    dkms install -m brcmfmac-nexmon-dkms -v 6.6 -k $mod --force
	fi
	
    fi
done
popd

echo "+ Holding firmware-brcm80211 to avoid updating and overwriting nexmon custom firmware"
apt-mark hold firmware-brcm80211

# look for nexmon artifacts
if pushd "${PWNY_BUILD_ARTIFACTS}/nexmon" 2>/dev/null; then
    figlet artifacts
    tar -czf - . | tar -C / -tzf -
    printenv
    popd
else
    echo "* No nexmon artifacts found"
fi

if [ -f /usr/lib/firmware/NEXMON_INSTALLED ]; then
    echo "Nexmon firmware already installed"
    exit 0
fi

nexmon_unpacked=0
UnpackNexmonSource () {
    # download or unpack nexmon
    NEXMON_TARFILE="${OVERLAY_DIR}/pwnagotchi/files/nexmon-dev.zip"
    pushd /usr/local/src
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
	    git clone --depth=1 $NEXMON_REPO nexmon
	fi
    fi
    #if [ "${nexmon_unpacked}" = 0 ]; then
    cd nexmon
    touch DISABLE_STATISTICS
    if [ ! "${NEXMON_ROOT}" ]; then
	echo "* Setting up build environment"
	source setup_env.sh
	make
	export nexmon_unpacked=1
    fi

    popd
}

# build utility
if [ ! -f /usr/bin/nexutil ]; then
    echo "+ Building nexutil"
    UnpackNexmonSource
    pushd utilities/nexutil
    make
    make install
    BUILT_ONE=true
    popd
else
    ls -l /usr/bin/nexutil
fi
save_pwny_artifact /usr/bin/nexutil nexmon/usr/bin

# build Nexmon patched firmware, using last kernel version "mod"
echo "* --> Building patched firmware"
export KERNEL_REV=$(echo $mod | sed 's/\([0-9]\+\.[0-9]\+\)\..*/\1/')
for p in $NEXMON_PATCHES; do
    echo "Loop $p"
    UnpackNexmonSource

    pushd nexmon/patches/$p/nexmon

    sed -i -e 's#^KERNEL_VERSION = .*$#KERNEL_VERSION = \$(if $(KERNEL_REV),\$(KERNEL_REV),\$(shell uname -r | sed "s/\\([0-9]\\+\\.[0-9]\\+\\)\\..*/\\1/"))#' Makefile
    
    # instead of building the module, let it find the local file
    # actual module is built with dkms above
    echo "    ===---> make clean $p"
    QEMU_UNAME=$mod KERNEL_REV=${KERNEL_REV} make clean-firmware || true
    RAMFILE=$(cat ${NEXMON_ROOT}/firmwares/$p/definitions.mk | grep RAM_FILE | cut -d = -f 2)
    echo "    ===---> patch firmware $p: ${RAMFILE}"
    make ${RAMFILE}
    echo "    ===+++> install patched firmware $p/${RAMFILE}"
    # use invalid kernel number so install-firmware
    # skips module unloading and loading

    # patch the Makefile to not build brcmfmac.ko, just the firmware
    sed -i -e '/^install-firmware:.* brcmfmac.ko/s/ brcmfmac.ko//' Makefile

    QEMU_UNAME=4.20.69 make install-firmware || true

    grep -A 7 install-firmware Makefile
    BUILT_ONE=true
    echo ${RAMFILE}
    ls -l ${RAMFILE}
    if [[ ${RAMFILE} == brcmfmac* ]]; then
	save_pwny_artifact ${RAMFILE} nexmon/lib/firmware/brcm
    fi

    popd
done
popd

# system specific configuration
if [ "${BOARD}" == "bananapim4zero" ]; then
    pushd /usr/lib/firmware
    if [ ! -f  updates/brcm/cyfmac43455-sdio.bin.ORIG ]; then
	echo "Saving backup of original cyfmac43455 firmware"
	mv updates/brcm/cyfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin.ORIG
    fi
    echo "Copying nexmon 43455 firmware to updates/brcm/cyfmac43455-sdio.bin"
    cp -f brcm/brcmfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin
    save_pwny_artifact brcm/brcmfmac43455-sdio.bin nexmon/updates/brcm/cyfmac43455-sdio.bin

    # keep old style saving for now
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
	echo -n "Link 43430->43436s exists: "
	ls -l /usr/lib/firmware/brcm/brcmfmac43436s-sdio.bin
    fi
    save_pwny_artifact /usr/lib/firmware/brcm/brcmfmac43436s-sdio.bin nexmon/usr/lib/firmware/brcm
fi

(echo NEXMON BRCMFMAC firmware installed; date) >/usr/lib/firmware/NEXMON_INSTALLED

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
