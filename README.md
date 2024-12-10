# pwny-builder
Build pwnagotchis using armbian-build and eventually pi-gen and others

Work in progress. I have armbian-build working using some modified pi-gen scripts (that probably don't work in pi-gen anymore). I can build pwnagotchi for a few different boards that are supported by Armbian. I will eventually check that in here.

## pi-gen
This started with [pi-gen](https://github.com/RPi-Distro/pi-gen.git). The scripts have been changed a lot, but the structure was maintained.  I want to get them working in pi-gen again.

## armbian-build
These currently work with [armbian-build](https://github.com/armbian/build), and make a working pwnagotchi for bananapim4zero (both versions). Any other example configs have not been well tested.
To build a pwnagotchi:

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
Flash to an SD card using Raspberry Pi Imager, Balena etcher, or other. Do not apply OS customizations (user, wifi network, etc) as part of the flash.
