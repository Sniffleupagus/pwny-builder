#!/bin/bash -e

# install nexmon
NEXMON_REPO=https://github.com/DrSchottky/nexmon.git

# raspberry pi defaults
NEXMON_PATCHES="patches/bcm43430a1/7_45_41_46/nexmon patches/bcm43455c0/7_45_206/nexmon patches/bcm43436b0/9_88_4_65/nexmon"

if [ ${BOARD} == "bananapim4zero" ]; then
    NEXMON_PATCHES="patches/bcm43455c0/7_45_206/nexmon"
fi

PHOME=/home/pwnagotchi

cd /usr/local/src

mkdir -p ${PHOME}/git
pushd ${PHOME}/git

NEXMON_TARFILE="/tmp/overlay/pwnagotchi/files/nexmon.zip"
NEXMON_URL="https://github.com/DrSchottky/nexmon/archive/refs/heads/dev.zip"

if [ ! -d nexmon ]; then
    if [ -f "${NEXMON_TARFILE}" ]; then
	echo
	echo "=== Unpacking nexmon tarball ${NEXMON_TARFILE}"
	unzip -q ${NEXMON_TARFILE}
	if [ -d nexmon-dev ]; then
	    mv nexmon-dev nexmon
	fi
    else
	echo "+-> Downloading nexmon.zip"
	curl -o nexmon.zip -L ${NEXMON_URL}
	if [ -f nexmon.zip ]; then
	    echo "+-> Unpacking nexmon.zip"
	    unzip -q nexmon.zip
	    mv nexmon-dev nexmon
	    rm nexmon.zip
	else
	    echo "=== cloning nexmon repository ${NEXMON_REPO}"
	    git clone --depth=1 $NEXMON_REPO
	fi
    fi
    cd nexmon
else
    cd nexmon
fi

BUILT_ONE=false

if [ -f "/boot/armbianEnv.txt" ]; then
    # -DDEBUG in the driver does not compile on armbian
    echo "* --> Removing -DDEBUG from driver Makefile"
    pushd patches/driver/brcmfmac_6.6.y-nexmon
    sed -i '/-DDEBUG$/d' Makefile
    sed -i 's/include \\$/include/' Makefile
    popd
fi

source setup_env.sh
make

if [ ! -f /usr/bin/nexutil ]; then
    pushd utilities/nexutil
    make
    make install
    BUILT_ONE=true
    popd
    mkdir -p /tmp/pwny_parts/usr/bin
    cp /usr/bin/nexutil /tmp/pwny_parts/usr/bin
fi

# for each kernel with a build directory
ls /lib/modules
uname -a

for mod in $(cd /lib/modules ; ls); do

    if [ -d /lib/modules/$mod/build ]; then
	echo
	echo ">>>---> building Nexmon for $mod"

	export QEMU_UNAME=$mod
	export PLATFORMUNAME=$mod
	uname -a

	export KERNEL=$(echo $mod | cut -d . -f -2)
	MOD_DEST=/lib/modules/${mod}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac

	# checking for installed kernel module, and not re-installing
	# delete brcmfmac.ko.NEXMON to rebuild for that kernel tree
	if [ ! -f ${MOD_DEST}/brcmfmac*NEXMON ]; then
	    for p in $NEXMON_PATCHES; do
		echo "    ===---> clean $mod patch $p"
		pushd $p
		make clean || true
		popd
	    done

	    for p in $NEXMON_PATCHES; do
		echo "    ===--->  build $mod patch $p"
		pushd $p
		make
		echo "    ===+++>  install $mod patch $p"
		# use invalid kernel number so install-firmware
		# skips module unloading and loading
		QEMU_UNAME=4.20.69 make install-firmware || true
		BUILT_ONE=true
		popd
	    done

	    # built a new driver module while building firmwares above, so copy it into place
	    echo cp ${PHOME}/git/nexmon/patches/driver/brcmfmac_${KERNEL}.y-nexmon/brcmfmac.ko ${MOD_DEST}/brcmfmac.ko.NEXMON
	    cp ${PHOME}/git/nexmon/patches/driver/brcmfmac_${KERNEL}.y-nexmon/brcmfmac.ko ${MOD_DEST}/brcmfmac.ko.NEXMON

	    pushd ${MOD_DEST}
	    if [ -f brcmfmac.ko.xz -o -f brcmfmac.ko.xz.ORIG ]; then
		if [ -f brcmfmac.ko.xz.ORIG ]; then
		    # dont overwrite ORIG (again)
		    rm -f brcmfmac.ko.xz
		else
		    # save original
		    echo "  > Back up original driver"
		    mv brcmfmac.ko.xz brcmfmac.ko.xz.ORIG
		fi
		echo "   > Compressing driver"
		which xz
		xz --verbose -c brcmfmac.ko.NEXMON > brcmfmac.ko.xz

		# copy to /tmp/pwny_parts
		mkdir -p /tmp/pwny_parts/${MOD_DEST}
		cp brcmfmac.ko.xz brcmfmac.ko.NEXMON /tmp/pwny_parts/${MOD_DEST}
	    elif [ -f brcmfmac.ko ]; then
		if [ -f brcmfmac.ko.ORIG ]; then
		    rm -f brcmfmac.ko
		else
		    echo "  > Back up original driver"
		    mv brcmfmac.ko brcmfmac.ko.ORIG
		fi
		echo "  > Copying new driver"
		cp brcmfmac.ko.NEXMON brcmfmac.ko
		# copy to /tmp/pwny_parts
		mkdir -p /tmp/pwny_parts/${MOD_DEST}
		cp brcmfmac.ko brcmfmac.ko.NEXMON /tmp/pwny_parts/${MOD_DEST}
	    fi
	    
	    echo "++> Installed ${mod} kernel driver"
	    ls -l
	    popd
	else
	    echo -n "-=> Already installed ${mod}"
	fi
	
    else
	echo
	echo "=== NO Kernel build tree for  $mod ==="
	echo "--- Skipping Nexmon"
    fi
done

if [ ${BOARD} == "bananapim4zero" ]; then
    echo "Finished building nexmon"
    pushd /usr/lib/firmware
    if [ ! -f  updates/brcm/cyfmac43455-sdio.bin.ORIG ]; then
	echo "Saving backup of original cyfmac43455 firmware"
	mv updates/brcm/cyfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin.ORIG
    fi
    echo "Copying nexmon 43455 firmware to updates/brcm/cyfmac43455-sdio.bin"
    cp -f brcm/brcmfmac43455-sdio.bin updates/brcm/cyfmac43455-sdio.bin

    exit
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
    depmod -a
    echo " *> Saving all nexmon products"
    INCOMING=/tmp/pwny_parts
    pushd /
    tar -cvvzf ${INCOMING}/nexmon_backup.tar.gz \
	lib/modules/*/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac \
	lib/firmware/brcm/brcmfmac43{430,455,436,436s}-sdio.bin usr/bin/nexutil
    popd
fi

