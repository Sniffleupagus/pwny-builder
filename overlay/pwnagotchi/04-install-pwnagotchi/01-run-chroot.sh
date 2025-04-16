#!/bin/bash -e

# set these up in environment, probbaly build tool config file
# use the capital letter version, like:
#
# PWNY_RNDIS=YES
# PWNY_DEAUTH=true
# PWNY_DISPLAY=displayhatmini
#
myrndis=${PWNY_RNDIS:-YES}                      # enable RNDIS or not
mydeauth=${PWNY_DEAUTH:-false}                  # deauth enabled for config.toml
mydisplay=${PWNY_DISPLAY:-waveshare_3}          # type of display for config.toml, maybe /boot/config.txt
mytouchscreen=${PWNY_TOUCHSCREEN:-YES}          # enable goodix touchscreen overlay
mybluetooth=${PWNY_BLUETOOTH:-"NO"}             # host mac address for bt-tether in config.toml
mybtipaddr=${PWNY_BTIPADDR:-"172.20.10.7"}      # pwny ip address for bt-tether

CONFIGTOML="/etc/pwnagotchi/config.toml"

#mybluetooth="B8:49:6D:16:7A:1A"
#mybtaddr="172.20.10.16"
pwnyrepo=${PWNY_REPO:-"https://github.com/Sniffleupagus/pwnagotchi-snflpgs"} # pwnagotchi repo to install
pwnybranch=${PWNY_BRANCH:-"snflpgs"}

# activate venv for pip installs
. /home/pwnagotchi/.venv/bin/activate

pushd /home/pwnagotchi
mkdir -p git
cd git
if [ ! -d pwnagotchi ]; then
    if [ "${pwnybranch}" ]; then
	echo "Checking out ${pwnybranch}"
	git clone -b ${pwnybranch} ${pwnyrepo} pwnagotchi
    else
	git clone ${pwnyrepo} pwnagotchi	
    fi
fi
cd pwnagotchi

uname -a

#echo "Installing OPi.GPIO package"
#pip3 install 'git+https://github.com/Sniffleupagus/OPi.GPIO@BPIm4zero#egg=OPi.GPIO'
#pushd /home/pwnagotchi/.venv/lib/*/site-packages
#ln -s OPi RPi
#popd

echo "Installing RPi.GPIO fork for both versions of Bananapim4zero"
pip3 install 'git+https://github.com/Sniffleupagus/RPi.GPIO#egg=RPi.GPIO'

echo pip3 install -r requirements.txt
pip3 install -r requirements.txt

echo "+ Downgrading gym and stable_baselines3 for compatability"
pip install git+https://github.com/CeyaoZhang/gym.git@v0.21.0
pip3 install stable_baselines3==1.8.0

echo "+ 'Installing' pwnagotchi into ~pwnagotchi/.venv with symlinks"

ln -sf $(pwd)/pwnagotchi /home/pwnagotchi/.venv/lib/python*/site-packages/
ln -sf $(pwd)/bin/pwnagotchi /usr/local/bin/
sed -i -e 's/^#\/usr\/bin\/python3/#\/home\/pwnagotchi\/.venv\/bin\/python3/' bin/pwnagotchi

pushd builder/data

    pushd usr/bin
    echo "++> Installing executables"
    for f in *; do
	echo cp $f /usr/bin/$f
	cp -v $f /usr/bin/$f
	chmod 755 /usr/bin/$f
    done
    popd

    pushd etc
    
    echo "++> Installing config files into /etc: $(ls)"
    if [ -f /etc/rc.local ]; then
	echo "+ bring usb0/RNDIS up in /etc/rc.local"
	sed -i '/^exit 0/inmcli conn up usb0' /etc/rc.local
	
	echo "+ backing up /etc/rc.local for after first boot"
	cp /etc/rc.local /etc/rc.local.ORIG
    fi
    for i in *; do
	echo cp -rp $i /etc/
	cp -rvp $i /etc/
	chmod -R a+rX /etc/$i
    done
    echo "Board is ${BOARD}"
    if [[ "${BOARD}" == "bananapim4zero" ]]; then
	echo "Setting up RNDIS on usb0 for ${BOARD}"
	cd /etc/network/interfaces.d
	# doesn't need this anymore. second port shows up as usb0 on Armbian, but usb1 on DIB
	mv usb0-cfg usb1-cfg
	sed -i 's/usb0/usb1/g' usb1-cfg
    else
	echo "WRONG BOARD, but Setting up RNDIS on usb1 anyways"
	cd /etc/network/interfaces.d
    fi
    popd
    sleep 10
    ls -l
    if [ -d boot -a -f /boot/extlinux/extlinux.conf ]; then
	cd /etc/network/interfaces.d
	# doesn't need this anymore. second port shows up as usb0 on Armbian, but usb1 on DIB
	mv usb0-cfg usb1-cfg
	sed -i 's/usb0/usb1/g' usb1-cfg

	for dts in $(find boot -name \*.dts); do
	    dtb="/$(dirname ${dts})/$(basename ${dts} .dts).dtb"
	    mkdir -p "$(dirname ${dtb})"
	    echo "* Compiling ${dts} to ${dtb}"
	    /usr/bin/dtc -I dts -O dtb -o "$dtb" "$dts"
       	done
    fi

popd

gitDownload () {
    pkg=$1
    repo=${2:-jayofelony}
    dir=${3:-${pkg}}
    
    echo git clone http://github.com/$repo/$pkg $dir
    git clone http://github.com/$repo/$pkg $dir
    
}

echo "+++++ Installing Custom Plugins +++++++"
custom_plugins="/usr/local/share/pwnagotchi/custom-plugins"
mkdir -p ${custom_plugins}

installPlugins() {
    repo=$1
    dest=${2:-$(basename $repo .git)}
    subdir=${3:-''}
    matches=${4:-'*.py *.png'}
    install_dest=${5:-${custom_plugins}}

    pushd /home/pwnagotchi/git
    if [ -d $dest ]; then
	echo "*** -> $dest exists already - Skipping $repo"
    else
	git clone $repo $dest
	cd $dest/$subdir
	# symlink all of the python files to custom plugins dir
	for i in $matches; do
	    if [[ -e "$i" && ! -e "${install_dest}/$i" ]]; then
		echo ln -sF $(pwd)/$i ${install_dest}/
		ln -sF $(pwd)/$i ${install_dest}/
	    else
		echo "* -----> Skipping $i"
	    fi
	done
    fi
    popd
}

# installPlugins REPO [local_name] [subdirectory] [match_files] [destination]
# - REPO: https://github.com/USER/REPO.git
# - local_name: default same as REPO or specified
# - subdirectory: link files from within a subdirectory instead of repo top level
# - match_files: files/dirs to link into the custom plugins dir. default "*.py *.png"
# - destination: location to link files into, usually the custom plugins directory

echo "++>  Sniffleupagus pwnagotchi_plugins"
installPlugins https://github.com/Sniffleupagus/pwnagotchi_plugins pwnagotchi_plugins '' '[^T]*'

echo "++>  Sniffleupagus pisugar3 plugin"
installPlugins https://github.com/Sniffleupagus/pwnagotchi-plugin-pisugar3

echo "++> GPSD-easy"
installPlugins https://github.com/rai68/gpsd-easy.git

echo "++> NeonLightning plugins"
installPlugins https://github.com/NeonLightning/pwny.git neonlightning-plugins

echo "++> Spotify plugin"
installPlugins https://github.com/itsOwen/PwnSpotify.git

echo "++> HannahDiamond plugins"
installPlugins https://github.com/hannadiamond/pwnagotchi-plugins.git hannahdiamond-plugins plugins ups_hat_c.py

echo "++> FancyGotchi"
installPlugins https://github.com/V0r-T3x/Fancygotchi.git

echo "++> FancyGotchi 2.0 themes"
installPlugins https://github.com/V0r-T3x/Fancygotchi_themes.git Fancygotchi_themes fancygotchi_2.0 themes

echo "--> Wardriver"
installPlugins https://github.com/cyberartemio/wardriver-pwnagotchi-plugin.git wardriver-pwnagotchi-plugin "" 'wardriver.py wardriver_assets'

echo "--> Wall of Flippers - holy shit"
cd /root && git clone https://www.github.com/cyberartemio/Wall-of-Flippers && cd Wall-of-Flippers
echo "--> --> Creating WoF venv"
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt && deactivate
echo "--> --> Setting up wof.service"
cat >/etc/systemd/system/wof.service <<EOF
[Unit]
Description=WallofFlippers - A simple and easy way to find Flipper Zero Devices and Bluetooth Low Energy Based Attacks

[Service]
ExecStart=/root/Wall-of-Flippers/.venv/bin/python /root/Wall-of-Flippers/WallofFlippers.py --no-ui wof -d 0
WorkingDirectory=/root/Wall-of-Flippers/
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=wof
User=root
Group=root
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

systemctl enable wof.service

echo "--> --> Wall-of-Flippers plugin"
installPlugins https://github.com/cyberartemio/wof-pwnagotchi-plugin.git wof-pwnagotchi-plugin '' 'wof.py wof_assets'

echo "<-- Finished with Wall of Flippers"

echo "--> Pwnagotchi utils"
pwny_bindir="/home/pwnagotchi/bin"
mkdir -p ${pwny_bindir}

if [ ! -d pwnagotchi-utils ]; then
    echo "++> installing Sniffleupagus utils"
    gitDownload pwnagotchi-utils Sniffleupagus pwnagotchi-utils

    cd pwnagotchi-utils
    for i in *; do
	echo ln -s $(pwd)/$i ${pwny_bindir}/
	ln -sF $(pwd)/$i ${pwny_bindir}/
    done
fi

# set up crontab to restart bettercap wifi.recon
echo "--> Creating crontab for user pwnagotchi"
cat >/var/spool/cron/crontabs/pwnagotchi <<EOF
# m h  dom mon dow   command
*/3 *  *   *   *     /home/pwnagotchi/.venv/bin/python3 /home/pwnagotchi/bin/bcinfo.py -qw >/dev/null 2>&1
EOF

mkdir -p /etc/pwnagotchi

echo "--> Creating default config.toml with display ${mydisplay}"
cat >${CONFIGTOML} <<EOC
ui.web.username = "pwny"
ui.web.password = "pwny1234"
ui.display.enabled = true
ui.display.type = "${mydisplay}"
main.custom_plugins = "/usr/local/share/pwnagotchi/custom-plugins"
main.plugins.led.enabled = false
main.plugins.auto-update.enabled = false
main.plugins.morse_code.enabled = true
main.plugins.morse_code.led = "/sys/class/leds/red:status/brightness"
personality.deauth = ${mydeauth}
personality.throttle_a = 0.3
personality.throttle_d = 0.9
personality.deauth_prob = 0.2
personality.assoc_prob = 0.9

bettercap.handshakes = "/root/handshakes/"

ui.backgroundcolor="#ffffff"
ui.foregroundcolor="#000000"
ui.colormode="1"
main.whitelist = [
	       "01:02:03:04:05:06"
        ]

main.plugins.rss_voice.enabled = true
main.plugins.rss_voice.path = "/root/voice_rss"
main.plugins.rss_voice.feed.wait.url = "https://www.reddit.com/r/pwnagotchi/comments.rss"
main.plugins.rss_voice.feed.bored.url = "https://www.reddit.com/r/pwnagotchi.rss"
main.plugins.rss_voice.feed.sad.url = "https://www.reddit.com/r/showerthoughts.rss"
EOC


if [ ${mybluetooth} != 'NO' ]; then
    cat >>${CONFIGTOML} <<EOC
main.plugins.bt-tether.enabled = true
main.plugins.bt-tether.devices.iphone.enabled = true
main.plugins.bt-tether.devices.iphone.search_order = 3
main.plugins.bt-tether.devices.iphone.mac = "${mybluetooth}"
main.plugins.bt-tether.devices.iphone.ip = "${mybtipaddr}"
main.plugins.bt-tether.devices.iphone.netmask = 24
main.plugins.bt-tether.devices.iphone.interval = 1
main.plugins.bt-tether.devices.iphone.scantime = 15
main.plugins.bt-tether.devices.iphone.max_tries = 0
main.plugins.bt-tether.devices.iphone.share_internet = false
main.plugins.bt-tether.devices.iphone.priority = 15
EOC
fi


#
# /boot
#

# /boot/config.txt on raspberry pi
if [ -f /boot/config.txt ]; then
    echo "Configuring /boot/config.txt on Raspberry Pi Probably"
    if ! grep "pwnagotchi additions" /boot/config.txt; then

	cat >>/boot/config.txt <<EOC
#
# pwnagotchi additions
#
EOC

	echo "Setting up boot config options"
    
	if [ $myrndis == 'NO' ]; then
	    echo "-- no RNDIS"
	    comment='#'
	else
	    echo "-- yes RNDIS"
	    if ! grep g_ether /boot/cmdline.txt; then
		echo 'Modifying cmdline.txt for g_ether/RNDIS'
		sed -i '1 s/.*/& modules-load=dwc2,g_ether/' /boot/cmdline.txt
	    fi
	    comment=''
	fi
	cat >>/boot/config.txt <<EOC
# dwc2 for RNDIS, OTG usb. comment out for X306 usb battery hat
${comment}dtoverlay=dwc2

EOC

	cat >>/boot/config.txt <<EOF
# enable i2c and spi for screens"
dtoverlay=spi1-3cs
dtparam=i2c1=on
dtparam=i2c_arm=on
dtparam=spi=on

gpu_mem=16

#### audio out on pins 18 and 19
#dtoverlay=audremap,pins_18_19

EOF

	if [ $mytouchscreen != 'NO' ]; then
	    comment=''
	else
	    comment='#'
	fi

	cat >>/boot/config.txt <<EOC
#### touchscreen on waveshare touch e-paper
${comment}dtoverlay=goodix,interrupt=27,reset=22

EOC

	if [ $mydisplay = 'displayhatmini' ]; then
	    comment=''
	else
	    comment='#'
	fi
    
	cat >>/boot/config.txt <<EOC
#### for PWM backlighting on pimoroni displayhatmini
${comment}dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4

EOC
    fi
    echo "ok"
fi

if ! grep "g_ether" /etc/modules; then
    # if g_ether isn't set up in /boot/config.txt (raspberry pi)
    # add it to /etc/modules (armbian, debian-image-builder)
    echo "g_ether" >>/etc/modules
fi

if [ -f /boot/bananapiEnv.txt ]; then
    echo "--- ???????-  Configure bananapi armbian-esque image"
    echo
    echo "--- ???????-   ummm.  do the dtbs here?"
fi

# configure armbianEnv for i2c, spi and "new" wifi chip (does not seem to impact old board)
if [ -f /boot/armbianEnv.txt ]; then
    echo "+*+*+*+*+*+ Configuring armbian +*+*+*+*+*+"
    
    OVERLAYS="overlays=\""

    if [[ "$BOARD" == "bananapim4zero" ]]; then
	echo "+-=-=- Configure bananapim4zero DTB hacks"
	pushd /boot/dtb/allwinner
	echo "*** Changing SPI1 MISO to PC4 to avoid clash with displayhatmini"
	mv sun50i-h618-bananapi-m4-zero.dtb sun50i-h618-bananapi-m4-zero.dtb.ORIG
	dtc -I dtb -O dts sun50i-h618-bananapi-m4-zero.dtb.ORIG | sed 's/pins = \"PH6\\0PH7\\0PH8/pins = \"PH6\\0PH7\\0PC4/' | dtc -I dts -O dtb -o sun50i-h618-bananapi-m4-zero.dtb.V1
	cp sun50i-h618-bananapi-m4-zero.dtb.V1 sun50i-h618-bananapi-m4-zero.dtb

	# still need to fix "i2c4-pi" for V2. maybe as part of the V2 overlay
	dtc -I dtb -O dts sun50i-h618-bananapi-m4-zero.dtb.ORIG | sed 's/pins = \"PG15\\0PG16/pins = \"PI5\\0PI6/' | dtc -I dts -O dtb -o sun50i-h618-bananapi-m4-zero.dtb.V2

	cd overlay
	echo "+++ Creating i2c4-pg.dtbo for Pisugar i2c pins"
	mkdir /boot/overlay-user
	dtc -I dtb -O dts sun50i-h616-i2c4-ph.dtbo | sed 's/i2c4_ph_pins/i2c4_pg_pins/' | dtc -I dts -O dtb -o sun50i-h616-i2c4-pg.dtbo
	
	popd    
    
	OL_LIST="i2c4-pg spidev0_0 spidev1_1"
    else
	echo "***** CONFIGURING NOT BANANA!!!"
	OL_LIST="spidev1_1"
    fi
    OVERLAYS="overlays=${OL_LIST}"
    if grep "^overlays=" /boot/armbianEnv.txt; then
	sed -i "s#^overlays=.*#${OVERLAYS}#" /boot/armbianEnv.txt
    else
	echo ${OVERLAYS} >>/boot/armbianEnv.txt
    fi
    
#    if grep "^user_overlays=" /boot/armbianEnv.txt; then
#	sed -i "s#^user_overlays=.*#user_overlays=sun50i-h616-i2c4-pg.dtbo#" /boot/armbianEnv.txt
#    else
#	echo "user_overlays=sun50i-h616-i2c4-pg.dtbo">>/boot/armbianEnv.txt
#    fi
    echo "==== armbianEnv.txt:"
    cat /boot/armbianEnv.txt
fi

ls -l /boot

#echo "Setting up /boot/handshakes directory, linked to /root/handshakes"
#mkdir -p -m 0777 /boot/handshakes
#ln -s /boot/handshakes /root/handshakes
echo "Setting up /root/handshakes"
mkdir -p -m 0777 /root/handshakes


# Debian Image Builder stuff
EXTLINUXCONF=/boot/extlinux/extlinux.conf
if [ -f ${EXTLINUXCONF} ]; then
    echo "===-----> Configuring extlinux overlays:"
    # use predictable network names
    sed -i -e 's/net.ifnames=0 //' ${EXTLINUXCONF}
    sed -i -e '/^#fdtoverlays /d' ${EXTLINUXCONF}
    cat >>${EXTLINUXCONF} <<EOF
        # BANANA PI M4 ZERO V1
        #fdtoverlays ../allwinner/overlays/sunxi-h616-pg-15-16-i2c4.dtbo ../allwinner/overlays/sunxi-h616-spi1-cs1-spidev.dtbo ../allwinner/overlays/sunxi-h616-pg-6-7-uart1.dtbo
        # BANANA PI M4 ZERO V2
        fdtoverlays ../allwinner/overlays/sunxi-h618-bananapi-m4-sdio-wifi-bt.dtbo ../allwinner/overlays/sunxi-h616-pi-5-6-i2c0.dtbo ../allwinner/overlays/sunxi-h616-spi1-cs1-spidev.dtbo ../allwinner/overlays/sunxi-h616-pi-13-14-uart4.dtbo
EOF

	
    echo "=========== Result:"
    cat ${EXTLINUXCONF}
fi
if [ -f board.txt ]; then
    echo "====------> Adding overlays to board.txt"
    sed -i "s#^FDTOVERLAYS=.*#FDTOVERLAYS='${FDTOVERLAYS}'#" board.txt
    echo "Result:"
    grep fdtoverlays board.txt
fi

# set host and dev ID on g_ether, so not random.
if [ ! -f /etc/modprobe.d/g_ether.conf ]; then
   echo "--> Setting up g_ether device IDs"
   echo "options g_ether use_eem=0 host_addr=f0:0d:ba:be:f0:0d dev_addr=58:70:77:6e:79:58" > /etc/modprobe.d/g_ether.conf
fi

# old network server. set it to ignore wlan0 so wpa-supplicant doesn't fight with pwny
if [ -d /etc/dhcpcd ]; then
    if ! grep "pwnagotchi additions" /etc/dhcpcd/dhcpcd.conf ; then
	
	echo "# pwnagotchi additions" >>/etc/dhcpcd/dhcpcd.conf
	echo "denyinterfaces wlan0" >>/etc/dhcpcd/dhcpcd.conf
    fi
fi

# services do not need to be started by the installation.  First boot will enable them
#systemctl enable bettercap pwngrid-peer pwnagotchi

echo "* Fixing file permissions"
chown -R pwnagotchi:pwnagotchi /home/pwnagotchi
chmod a+rX /root

echo "- Cleaning up caches"

rm -rf /root/go
rm -rf /root/.cache
rm -rf /var/cache/apt
rm -rf /usr/local/src/*
rm -rf /usr/local/go

echo "==== Woohoo! ===="
