# pwny-builder
Build pwnagotchis using armbian-build and eventually pi-gen and others

Work in progress. I have armbian-build working using some modified pi-gen scripts (that probably don't work in pi-gen anymore). I can build pwnagotchi for a few different boards that are supported by Armbian. I will eventually check that in here.

## pi-gen
This started with [pi-gen](https://github.com/RPi-Distro/pi-gen.git). The scripts have been changed a lot, but the structure was maintained.  I want to get them working in pi-gen again.

## armbian-build
These currently work in [armbian-build](https://github.com/armbian/build), and make a working pwnagotchi for bananapim4zero (both versions). Any other armvbian configs have not been well tested.
To use this with armbian-build, make a git clone of armbian-build. From this repo, copy **overlay, extensions, customize-image.sh** and **config-bananapwnm4zero.conf** into armbian-build/userpatches/

```
apt-get -y install git
# clone this repo
git clone https://github.com/Sniffleupagus/pwny-builder.git
# clone armbian-build
git clone https://github.com/armbian/build.git armbian-build
cd armbian-build
# copy the files from pwny-builder into userpatches
cp -rp ../pwny-builder/{overlay,extensions,customize-image.sh,config-bananapwnm4zero.conf} userpatches/
./compile.sh bananapwnm4zero
```
The build will download everything needed, set up a minimal armbian image, and install pwnagotchi and all of its dependencies.
