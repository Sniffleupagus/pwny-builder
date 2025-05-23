#!/bin/bash -e

figlet "artifacts"

echo "Rootfs: ${ROOTFS_DIR}, pwd: $(pwd)"
ls -l ${ROOTFS_DIR}/root

if [ "${ROOTFS_DIR}" -a "${ROOTFS_DIR}" != "/" -a -d ${ROOTFS_DIR}/root/artifacts ]; then
    figlet "Save Artifacts"
    cd ..
    echo "+ saving to $(pwd)"
    mkdir -p artifacts
    rsync -av ${ROOTFS_DIR}/root/artifacts/ artifacts/
    rm -r ${ROOTFS_DIR}/root/artifacts
fi

