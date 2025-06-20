#!/bin/bash -e


#echo "Skipping AIC8800 Driver"
#exit

figlet aic8800

echo "+++ Installing aic8800 Wifi USB drivers"
AIC8800_TYPE=${AIC8800_TYPE:-"usb"}

[[ -z $AIC8800_TYPE ]] && return 0
api_url="https://api.github.com/repos/radxa-pkg/aic8800/releases/latest"
latest_version=$(wget -q -O - "${api_url}" | jq -r '.tag_name')
aic8800_firmware_url="https://github.com/radxa-pkg/aic8800/releases/download/${latest_version}/aic8800-firmware_${latest_version}_all.deb"
aic8800_pcie_url="https://github.com/radxa-pkg/aic8800/releases/download/${latest_version}/aic8800-pcie-dkms_${latest_version}_all.deb"
aic8800_sdio_url="https://github.com/radxa-pkg/aic8800/releases/download/${latest_version}/aic8800-sdio-dkms_${latest_version}_all.deb"
aic8800_usb_url="https://github.com/radxa-pkg/aic8800/releases/download/${latest_version}/aic8800-usb-dkms_${latest_version}_all.deb"
if [[ "${GITHUB_MIRROR}" == "ghproxy" ]]; then
    ghproxy_header="https://mirror.ghproxy.com/"
    aic8800_firmware_url=${ghproxy_header}${aic8800_firmware_url}
    aic8800_pcie_url=${ghproxy_header}${aic8800_pcie_url}
    aic8800_sdio_url=${ghproxy_header}${aic8800_sdio_url}
    aic8800_usb_url=${ghproxy_header}${aic8800_usb_url}
fi
case "${AIC8800_TYPE}" in
    "pcie")
        aic8800_dkms_file_name=aic8800-pcie-dkms_${latest_version}_all.deb
        wget ${aic8800_pcie_url} -P /home/pwnagotchi
        ;;
    "sdio")
        aic8800_dkms_file_name=aic8800-sdio-dkms_${latest_version}_all.deb
	wget ${aic8800_sdio_url} -P /home/pwnagotchi
        ;;
    "usb")
        aic8800_dkms_file_name=aic8800-usb-dkms_${latest_version}_all.deb
        wget ${aic8800_usb_url} -P /home/pwnagotchi
        ;;
    *)
        return 0
        ;;
esac
wget ${aic8800_firmware_url} -P /home/pwnagotchi/
cd /home/pwnagotchi
echo "+ Building for $(dpkg --print-architecture) arch"

dpkg --install ./aic8800-firmware_${latest_version}_all.deb || true
dpkg --install ./${aic8800_dkms_file_name} || true

pushd /usr/src/aic8800-usb-*
. dkms.conf

for m in $(cd /lib/modules ; ls); do
    if [ -d /lib/modules/$m/build ]; then
	echo "* Building ${PACKAGE_NAME} for $m"
	if dkms build -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION} -k $m ; then
	    echo "+ Installing Driver for $m"
	    dkms install -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION} -k $m --force
	fi
    fi
done

