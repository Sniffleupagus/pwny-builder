#!/bin/bash -e

. /root/overlay/pwnagotchi/common.sh

echo "Copying files from $(pwd)"

pwd
ls -l
if ls -l ${ROOTFS_DIR}/usr/local/src/pytorch/dist/*.whl; then
    for f in ${ROOTFS_DIR}/usr/local/src/pytorch/dist/*.whl; do
	save_pwny_artifact $f torch/
    done
    
    for f in ${ROOTFS_DIR}/usr/local/src/vision/dist/*.whl; do
	save_pwny_artifact $f torch/
    done
fi

