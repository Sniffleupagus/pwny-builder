#
# Makefile for pwny-builder
#
# been a while since I made a makefile

ARMBIAN_VERSION=$(shell cat builders/armbian-build/VERSION)
KERNEL_VERSION=$(shell grep -A2 'current'  builders/armbian-build/config/sources/families/include/sunxi64_common.inc  | grep KERNELBRANCH | cut -d '"' -f 2 | cut -d v -f 2)
OUTPUT_IMAGE=output/images/Armbian-unofficial_$(ARMBIAN_VERSION)_Bananapim4zero_bookworm_current_$(KERNEL_VERSION).img
DEST_DIR=.

all: bananapwnm4zero-latest.img.xz

force-reimage:

bananapwnm4zero-latest.img.xz: $(OUTPUT_IMAGE)
	if ls -l $@; then \
		mv $@ $@.OLD; \
	fi
	xz -k -v -v -T 0 -c $< > $@
	outname=bananapwnm4zero
	/bin/bash -c "cp $@ $(DEST_DIR)/bananapwnm4zero-$$(date +%Y%m%d%H%M).img.xz"


$(OUTPUT_IMAGE): builders/armbian-build config-bananapwnm4zero.conf builders/armbian-build/output/config/linux-sunxi64-current.config force-reimage
	echo "Building $(OUTPUT_IMAGE)"
	cd builders/armbian-build && time ./compile.sh bananapwnm4zero

armbian-kernel:
	cd builders/armbian-build && time ./compile.sh bananapwnm4zero kernel

armbian-kconfig:
	cd builders/armbian-build && time ./compile.sh bananapwnm4zero kernel-config

builders/armbian-build:
	echo In `pwd`
	sleep 10
	mkdir -p builders
	cd builders
	git clone git@github.com:armbian/build armbian-build
	cd armbian-build
	ln -s $(dirname $(dirname $(pwd))) userpatches

