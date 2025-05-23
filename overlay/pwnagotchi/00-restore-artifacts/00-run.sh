#!/bin/bash -e


pwd

source ../common.sh

#
# Restore artifacts from previous builds and zip files
# to cache large repos for less internet usage
#

# copy pwnagotchi scripts to /tmp/overlay/pwnagotchi
# - similar to armbian-build overlay -> /tmp/overlay, but on pi-gen
#   /tmp gets mounted as tmpfs before the chroot and loses its contents
#   so using /root/overlay/pwnagotchi instead

echo "Starting in $(pwd). Root dir: ${ROOTFS_DIR}"
echo "Overlay: ${OVERLAY_DIR}"
echo "SDCARD: ${SDCARD}"
echo "AS: ${PWNY_ARTIFACT_SUB}"

if [ "${ROOTFS_DIR}" != "" -a "${ROOTFS_DIR}" != "/" ]; then
    if [ ! -d ${ROOTFS_DIR}${OVERLAY_DIR} ]; then
	echo "+ Creating ${OVERLAY_DIR}"
	mkdir -p ${ROOTFS_DIR}${OVERLAY_DIR}
    else
	ls -l ${ROOTFS_DIR}${OVERLAY_DIR}
    fi

    pushd ..
    echo "+ Copying pwnagotchi overlay to ${OVERLAY_DIR}"
    rsync --exclude '*~' --exclude '.#*' --exclude SKIP --exclude SKIP_IMAGES --exclude EXPORT_IMAGE -avz . ${ROOTFS_DIR}${OVERLAY_DIR}/
    popd
else
    echo Not copying overlay
fi
