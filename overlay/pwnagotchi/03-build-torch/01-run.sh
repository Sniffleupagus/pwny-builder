#!/bin/bash -e

echo "Copying files from $(pwd)"

if [ -f torch-packages]; then
    ls -l torch-packages
    cp torch-packages ${ROOTFS_DIR}/tmp/torch-packages
fi

if [ -d INCOMING_files ]; then
    cp INCOMING_files/* ${ROOTFS_DIR}/tmp
fi

ls -ltrh ${ROOTFS_DIR}/tmp
