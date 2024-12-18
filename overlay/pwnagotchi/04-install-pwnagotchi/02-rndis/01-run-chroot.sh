#!/bin/bash -e

myrndis=${PWNY_RNDIS:-YES}

if [[ "${myrndis}" != "YES" ]]; then
    exit
fi

echo "*** Configuring RNDIS"

# enable usb0 via nmcli
for rc in rc.local rc.local.ORIG; do
    if [ -f /etc/${rc} ]; then
	echo "|-+ bring usb0/RNDIS up in ${rc}"
	sed -i '/^exit 0/inmcli conn up usb0' /etc/${rc}
    fi
done

# Debian-image-builder for bananapi m4 zero uses usb1 for RNDIS
if [[ "${BOARD}" == "bananapim4zero" ]]; then
    if [[ "${BUILDER}" == "debian-image-builder" ]]; then
	echo "|-> Setting up RNDIS on usb1 for ${BOARD}"
	cd /etc/network/interfaces.d
	if [ -f usb0-cfg ]; then
	    mv usb0-cfg usb1-cfg
	    sed -i 's/usb0/usb1/g' usb1-cfg
	fi
    fi
fi

# set host and dev ID on g_ether, so not random RNDIS devices
if [ ! -f /etc/modprobe.d/g_ether.conf ]; then
   echo "|-> Setting up g_ether device IDs"
   echo "options g_ether use_eem=0 host_addr=f0:0d:ba:be:f0:0d dev_addr=58:70:77:6e:79:58" > /etc/modprobe.d/g_ether.conf
fi

echo "|-- RNDIS Configuration Complete"
