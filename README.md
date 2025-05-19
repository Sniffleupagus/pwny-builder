# pwny-builder
Build pwnagotchis using armbian-build and eventually pi-gen and others

Work in progress. I have armbian-build working using some modified pi-gen scripts (that probably don't work in pi-gen anymore). I can build pwnagotchi for a few different boards that are supported by Armbian. I will eventually check that in here.

## pi-gen
This started with [pi-gen](https://github.com/RPi-Distro/pi-gen.git). The scripts have been changed a lot, but the structure was maintained. These once again work with pi-gen, tested with a 64-bit build for a PiZero 2W. Symlink the overlay/pwnagotchi directory as a pwnagotchi stage in pi-gen:
```
git clone https://github.com/Sniffleupagus/pwny-builder.git
git clone --branch arm64 https://github.com/RPI-Distro/pi-gen.git
cd pi-gen
ln -s ../pwny-builder/overlay/pwnagotchi pwnagotchi
cat >config.pwnagotchi <<EOF
#!/bin/bash -x

export IMG_NAME="pwnagotchi"
export DEPLOY_COMPRESSION="xz"

export TARGET_HOSTNAME="pwnagotchi"

export LOCALE_DEFAULT=en_US.UTF-8
export KEYBOARD_KEYMAP="us"
export KEYBOARD_LAYOUT="English (US)"
export TIMEZONE_DEFAULT='US/Eastern'

export ENABLE_SSH=1

export STAGE_LIST="stage0 stage1 stage2 pwnagotchi"
EOF

sudo ./build.sh -c config.pwnagotchi
```

## armbian-build
These currently work with [armbian-build](https://github.com/armbian/build), and make a working pwnagotchi for bananapim4zero (both versions). Also tested building for a Radxa Zero 3W. The image boots, but did not get monitor mode with the built in wifi. 
To build a bananapwnm4zero pwnagotchi with armbian-build:

```
apt-get -y install git
# clone this repo
git clone https://github.com/Sniffleupagus/pwny-builder.git
git submodule init builders/armbian-build
cd builders/armbian-build
# symlink the root of this repo as "userpatches"
ln -s ../.. userpatches
./compile.sh bananapwnm4zero
```
The build will download everything needed, set up a minimal armbian image, and install pwnagotchi and all of its dependencies. The resulting image will be in builders/armbian-build/output/images, with a name like
```Armbian-unofficial_24.11.0-trunk_Bananapim4zero_bookworm_current_6.6.62.img```

## debian-image-builder
These scripts also work with [debian-image-builder](https://github.com/pyavitz/debian-image-builder). The resulting image mostly works with both versions of the BananaPi M4 Zero. It needs edits to the device tree overlays, depending on the board (see comments in /boot/extLinux/extLinux.conf).  Nexmon builds as a DKMS module for the V2 board. Pwnagotchi will likely work on other boards supported on this build, as long as there is a Wifi device with monitor mode.
To build with debian-image-builder:
```
git clone https://github.com/Sniffleupagus/pwny-builder.git
git clone https://github.com/pyavitz/debian-image-builder.git
cd debian-image-builder/files
rm -rf userscripts
ln -s ../../pwny-builder/overlay/pwnagotchi userscripts
cd ..
# set up userdata.txt to have USCRIPTS="1"
# tested only with bananapim4zero
make kernel board=bananapim4zero
make image board=bananapim4zero
```
Flash to an SD card using Raspberry Pi Imager, Balena etcher, or other. Do not apply OS customizations (user, wifi network, etc) as part of the flash.
