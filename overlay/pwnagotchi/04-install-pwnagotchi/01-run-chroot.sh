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
mydisplay=${PWNY_DISPLAY:-displayhatmini}       # type of display for config.toml, maybe /boot/config.txt
mytouchscreen=${PWNY_TOUCHSCREEN:-YES}          # enable goodix touchscreen overlay
mybluetooth=${PWNY_BLUETOOTH:-"NO"}             # host mac address for bt-tether in config.toml
mybtipaddr=${PWNY_BTIPADDR:-"172.20.10.7"}      # pwny ip address for bt-tether

# default locations
CONFIGTOML="/etc/pwnagotchi/config.toml"
custom_plugins="/usr/local/share/pwnagotchi/custom-plugins"

pwnyrepo=${PWNY_REPO:-"https://github.com/Sniffleupagus/pwnagotchi-snflpgs"} # pwnagotchi repo to install
pwnybranch=${PWNY_BRANCH:-""}

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

if [[ "${BOARD}" == "bananapim4zero" ]]; then
    echo "Installing RPi.GPIO fork for both versions of Bananapim4zero"
    pip3 install 'git+https://github.com/Sniffleupagus/RPi.GPIO#egg=RPi.GPIO'
else
    pip3 install RPi.GPIO
fi

echo pip3 install -r requirements.txt
pip3 install -r requirements.txt

echo "+ Downgrading gym and stable_baselines3 for compatability"
pip install git+https://github.com/CeyaoZhang/gym.git@v0.21.0
pip3 install stable_baselines3==1.8.0

echo "Board is ${BOARD}"
echo "+ 'Installing' pwnagotchi into ~pwnagotchi/.venv with symlinks"

ln -sf $(pwd)/pwnagotchi /home/pwnagotchi/.venv/lib/python*/site-packages/
ln -sf $(pwd)/bin/pwnagotchi /usr/local/bin/
sed -i -e 's/^#\/usr\/bin\/python3/#\/home\/pwnagotchi\/.venv\/bin\/python3/' bin/pwnagotchi

pushd builder/data

    pushd usr/bin
    echo "++> Installing executables"
    for f_bin in *; do
	echo "  \--> ${f_bin} to /usr/bin/${f_bin}"
	cp -v ${f_bin} /usr/bin/${f_bin}
	chmod 755 /usr/bin/${f_bin}
    done
    popd

    pushd etc
    echo "++> Installing config files into /etc: $(ls)"
    if [ -f /etc/rc.local ]; then
	echo "  + backing up /etc/rc.local for after first boot"
	cp /etc/rc.local /etc/rc.local.ORIG
    fi
    for i in *; do
	echo "  \--> $i to /etc/"
	cp -rvp $i /etc/
	chmod -R a+rX /etc/$i
    done
    popd

    if [ -d boot -a -f /boot/extlinux/extlinux.conf ]; then
	pwd
	ls
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
installPlugins https://github.com/Sniffleupagus/pwnagotchi_plugins pwnagotchi_plugins

echo "++>  Sniffleupagus pisugar3 plugin"
installPlugins https://github.com/Sniffleupagus/pwnagotchi-plugin-pisugar3

echo "++>  Sniffleupagus pwn-gpsd"
installPlugins https://github.com/Sniffleupagus/pwn-gpsd.git pwn-gpsd '' peer_map.py

echo "++> GPSD-easy"
installPlugins https://github.com/rai68/gpsd-easy.git

echo "++> Xentrify iPhone GPS"
installPlugins https://github.com/xentrify/custom-pwnagotchi-plugins.git xentrify-plugins '' iphone_gps.py

echo "++> NeonLightning plugins"
installPlugins https://github.com/NeonLightning/pwny.git neonlightning-plugins

echo "++> Spotify plugin"
installPlugins https://github.com/itsOwen/PwnSpotify.git

echo "++> HannahDiamond plugins"
installPlugins https://github.com/hannadiamond/pwnagotchi-plugins.git hannahdiamond-plugins plugins ups_hat_c.py

echo "  \--> Patching for configurable i2c bus"
pushd /home/pwnagotchi/git/hannahdiamond-plugins/plugins
patch <<EOF
diff --git a/plugins/ups_hat_c.py b/plugins/ups_hat_c.py
index 74a45b9..7ab1061 100644
--- a/plugins/ups_hat_c.py
+++ b/plugins/ups_hat_c.py
@@ -29,10 +29,10 @@ _REG_CALIBRATION = 0x05
 
 
 class UPS:
-    def __init__(self):
+    def __init__(self, i2c_bus=1):
         # only import when the module is loaded and enabled
         import smbus
-        self._bus = smbus.SMBus(1)
+        self._bus = smbus.SMBus(i2c_bus)
         self._addr = 0x43
 
         # Set chip to known config values to start
@@ -103,7 +103,7 @@ class UPSC(plugins.Plugin):
         self.ups = None
 
     def on_loaded(self):
-        self.ups = UPS()
+        self.ups = UPS(i2c_bus=self.options.get("i2c_bus", 1))
 
     def on_ui_setup(self, ui):
         if self.options["label_on"]:
EOF
popd

echo "++> FancyGotchi"
installPlugins https://github.com/V0r-T3x/Fancygotchi.git

echo "++> FancyGotchi 2.0 themes"
installPlugins https://github.com/V0r-T3x/Fancygotchi_themes.git Fancygotchi_themes fancygotchi_2.0 themes

pushd /home/pwnagotchi/git/Fancygotchi
mkdir -p themes
cp -rp /home/pwnagotchi/git/Fancygotchi_themes/fancygotchi_2.0/themes/* themes/
popd

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
StandardOutput=journal
StandardError=journal
SyslogIdentifier=wof
User=root
Group=root
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

# disabled for now. V2 boards do not have working bluetooth yet, V1 cannot pair while wof is going
# enable it through wof plugin webui
#systemctl enable wof.service

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
	echo "   \--> ln -s $(pwd)/$i ${pwny_bindir}/"
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
bettercap.handshakes = "/boot/handshakes/"

main.whitelist = [
  "Example_SSID",
  "01:02:03:04:05:06"
]

personality.deauth = ${mydeauth}
personality.throttle_a = 0.3
personality.throttle_d = 0.9
personality.deauth_prob = 0.2
personality.assoc_prob = 0.9

ai.enabled = false
main.plugins.auto_tune.enabled = true

main.plugins.auto-update.enabled = false
main.plugins.led.enabled = false
main.plugins.morse_code.enabled = true
main.plugins.morse_code.led = "/sys/class/leds/red:status/brightness"


ui.backgroundcolor="#ffffff"
ui.foregroundcolor="#000000"
ui.colormode="RGB"

main.plugins.IPDisplay.enabled = true

main.plugins.enable_assoc.enabled = true
main.plugins.enable_deauth.enabled = false
main.plugins.enable_deauth.behave_list = [ "my_home_network", "turns_off_deauths", "while_it_sees_these_nets" ]

main.plugins.memtemp.enabled = true
main.plugins.memtemp.scale = "celsius"
main.plugins.memtemp.orientation = "vertical"
main.plugins.memtemp.fields = "mem,cpu,temp,cpus"

main.plugins.tweak_view.enabled = true

main.plugins.ups_hat_c.enabled = false
main.plugins.ups_hat_c.label_on = true
main.plugins.ups_hat_c.bat_x_coord = 120
main.plugins.ups_hat_c.bat_y_coord = 0
main.plugins.ups_hat_c.shutdown = -5
main.plugins.ups_hat_c.i2c_bus = 0

main.plugins.pisugar3.enabled = false
main.plugins.pisugar3.shutdown = -5
main.plugins.pisugar3.i2c_bus = 4

main.plugins.gpsdeasy.enabled = false
main.plugins.gpsdeasy.fields = [ "fix", "lat", "lon", "spd", "alt" ]
main.plugins.gpsdeasy.speedUnit = "mph"
main.plugins.gpsdeasy.distanceUnit = "ft"
main.plugins.gpsdeasy.topleft_x = 130
main.plugins.gpsdeasy.topleft_y = 47
main.plugins.gpsdeasy.bettercap = true
main.plugins.gpsdeasy.host = "127.0.0.1"
main.plugins.gpsdeasy.port = 2947
main.plugins.gpsdeasy.device = "/dev/ttyS1"
main.plugins.gpsdeasy.disableAutoSetup = true

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

if ! grep "g_cdc" /etc/modules; then
    # if g_ether isn't set up in /boot/config.txt (raspberry pi)
    # add it to /etc/modules (armbian, debian-image-builder)
    echo "g_cdc" >>/etc/modules
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
    
	echo "*-- Bananapim4zero overlays: ${OL_LIST}"
	sed -i '/^overlays=.*$/d' /boot/armbianEnv.txt

	cat >>/boot/armbianEnv.txt <<EOF
# BananaPi M4 Zero V1
overlays=bananapi-m4-pg-15-16-i2c4 bananapi-m4-spi1-cs1-spidev bananapi-m4-pg-6-7-uart1
# BananaPi M4 Zero V2
# overlays=bananapi-m4-sdio-wifi-bt bananapi-m4-pi-5-6-i2c0 bananapi-m4-spi1-cs1-spidev bananapi-m4-pi-13-14-uart4
EOF

	echo "*-- Bananapim4zero - Selecting RTW88 Drivers"
	cat >/etc/modprobe.d/blacklist-bananapim4zero.conf <<EOF
#
# rtw88 drivers work better than 8821cu for pwnagotchi
#
#blacklist rtw88_8821c
#blacklist rtw88_8821cu
blacklist 8821cu
EOF
    else
	echo "***** Configuring Armbian overlays for not Bananapi M4 Zero!!!"
	OVERLAYS="overlays=spidev1_1"
	if grep "^overlays=" /boot/armbianEnv.txt; then
	    sed -i "s#^overlays=.*#${OVERLAYS}#" /boot/armbianEnv.txt
	else
	    echo ${OVERLAYS} >>/boot/armbianEnv.txt
	fi
    fi
    
    echo "==== armbianEnv.txt:"
    cat /boot/armbianEnv.txt
    echo	
fi

# Debian Image Builder stuff
EXTLINUXCONF=/boot/extlinux/extlinux.conf
if [ -f ${EXTLINUXCONF} ]; then
    echo "===-----> Configuring extlinux overlays:"
    FDTOVERLAYS="fdtoverlays"
    for ol in disable-uart0 gpu pg-i2c4 pg-uart1 ph-i2c1 spi0-spidev spi1-cs1-spidev; do
	echo "- ${ol}"
	FDTOVERLAYS="${FDTOVERLAYS} ../allwinner/overlays/sun50i-h616-${ol}.dtbo"
    done
    
    sed -i -e "s#\#fdtoverlays#${FDTOVERLAYS}#" ${EXTLINUXCONF}
    sed -i -e 's/console=ttyS0[^ ]//' ${EXTLINUXCONF}
    echo "Result:"
    grep fdtoverlays ${EXTLINUXCONF}
fi
if [ -f board.txt ]; then
    echo "====------> Adding overlays to board.txt"
    sed -i "s#^FDTOVERLAYS=.*#FDTOVERLAYS='${FDTOVERLAYS}'#" board.txt
    echo "Result:"
    grep fdtoverlays board.txt
fi

# old network server. set it to ignore wlan0 so wpa-supplicant doesn't fight with pwny
if [ -d /etc/dhcpcd ]; then
    if ! grep "pwnagotchi additions" /etc/dhcpcd/dhcpcd.conf ; then

	echo "*** Set dhcpcd.conf to ignore wlan0"
	echo "# pwnagotchi additions" >>/etc/dhcpcd/dhcpcd.conf
	echo "denyinterfaces wlan0" >>/etc/dhcpcd/dhcpcd.conf
    fi
fi

# services do not need to be started by the installation.  First boot will enable them
# after configuring
#systemctl enable bettercap pwngrid-peer pwnagotchi

echo "* Fixing pwnagotchi and /root file permissions"
chown -R pwnagotchi:pwnagotchi /home/pwnagotchi
chmod a+rX /root
echo "Setting up /boot/handshakes directory, linked to /root/handshakes"
mkdir -p -m 0777 /boot/handshakes
ln -s /boot/handshakes /root/handshakes

echo "- Cleaning up caches"
rm -rf /root/go
rm -rf /root/.cache
rm -rf /var/cache/apt
rm -rf /usr/local/src/*
rm -rf /usr/local/go
