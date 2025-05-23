#!/bin/bash -e

if [ "${ROOTFS_DIR}" -a "${ROOTFS_DIR}" != "/" -a -d ${ROOTFS_DIR}/root/artifacts ]; then
    figlet "Save Artifacts"
    cd ..
    mkdir -p artifacts
    rsync -av ${ROOTFS_DIR}/root/artifacts/ artifacts/
fi

