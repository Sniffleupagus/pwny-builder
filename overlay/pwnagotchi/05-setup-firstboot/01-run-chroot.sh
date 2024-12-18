#!/bin/bash -e

echo
echo "* Setting up first boot tasks"

if [ -f /boot/armbianEnv.txt ]; then
    echo "+ setting up Armbian /root/.not_logged_in_yet to preconfigure"
    cat >>/root/.not_logged_in_yet <<EOF
PRESET_NET_CHANGE_DEFAULTS=0
PRESET_NET_ETHERNET_ENABLED=0
PRESET_NET_WIFI_ENABLED=0
PRESET_NET_WIFI_COUNTRYCODE=GB

# System
SET_LANG_BASED_ON_LOCATION="y"
PRESET_LOCALE="en_US.UTF-8"
PRESET_TIMEZONE="Etc/UTC"

# Root
PRESET_ROOT_PASSWORD="pwny1234"
PRESET_ROOT_KEY=""

# User
PRESET_USER_NAME="pi"
PRESET_USER_PASSWORD="pwny1234"
PRESET_USER_KEY=""
PRESET_DEFAULT_REALNAME="Pi"
PRESET_USER_SHELL="bash"

EOF
fi

# change hostname from *pi to *pwn
hostname_current=$(cat /etc/hostname)
hostname_new=${hostname_new:-${hostname_current//pi/pwn}}

# disable /var/log/syslog because it fills up zram. use journalctl instead
#systemctl stop rsyslog syslog.socket
#systemctl disable rsyslog syslog.socket

# usb_modeswitch config for a couple of dongles I have that are not included
# usbmodeswitch for a69c:5721
cat >/etc/usb_modeswitch.d/a69c\:5721 <<EOF 
# COMFAST aic8800 
TargetVendor=0xa69c
TargetProduct=0x8d81
StandardEject=1
WaitBefore=5
EOF

cat >/etc/usb_modeswitch.d/0bda\:1a2b <<EOF
#  Wifi Dongle 8821au
TargetVendor=0x0bda
TargetProduct=0xc811
StandardEject=1
WaitBefore=5
EOF

# add COMFAST ID to udev rule
sed -i.bak "/LABEL=\"modeswitch_rules_end\"/i \
\# COMFAST WIFI6 aic8800\nATTR{idVendor}==\"a69c\", ATTR{idProduct}==\"5721\", RUN+=\"usb_modeswitch \'/%k\'\"\n" /usr/lib/udev/rules.d/40-usb_modeswitch.rules

sed -i "s/$hostname_current/$hostname_new/g" /etc/hosts
sed -i "s/$hostname_current/$hostname_new/g" /etc/hostname

# let NetworkMananger manage interfaces specified in /etc/network/interfaces.d
sed -i "s/^managed=false/managed=true/" /etc/NetworkManager/NetworkManager.conf
