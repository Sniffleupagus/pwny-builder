#!/bin/bash -e

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
echo "${OVERLAY_DIR}:"

if [ ! -d ${ROOTFS_DIR}${OVERLAY_DIR}/pwnagotchi ]; then
    echo "+ Creating ${OVERLAY_DIR}/pwnagotchi"
    mkdir -p ${ROOTFS_DIR}${OVERLAY_DIR}/pwnagotchi
else
    ls -l ${ROOTFS_DIR}${OVERLAY_DIR}/pwnagotchi
fi

if [ "${ROOTFS_DIR}" != "" -a "${ROOTFS_DIR}" != "/" ]; then
    pushd ..
    echo "+ Copying pwnagotchi overlay to ${OVERLAY_DIR}"
    rsync --exclude '*~' --exclude '.#*' --exclude SKIP --exclude SKIP_IMAGES --exclude EXPORT_IMAGE -avz . ${ROOTFS_DIR}${OVERLAY_DIR}/pwnagotchi/
    popd
fi

