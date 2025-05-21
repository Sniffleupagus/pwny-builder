#!/bin/bash -e

echo "Copying files from $(pwd)"

pwd
ls -l
ls -l ${ROOTFS_DIR}/usr/local/src/pytorch/dist/*.whl

mkdir -p INCOMING_files
cp ${ROOTFS_DIR}/usr/local/src/pytorch/dist/*.whl INCOMING_files
cp ${ROOTFS_DIR}/usr/local/src/vision/dist/*.whl INCOMING_files
ls -l INCOMING_files
