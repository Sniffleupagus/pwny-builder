#!/bin/bash -e

. ./common.sh

if [ ! -d "${ROOTFS_DIR}" ]; then
	copy_previous
fi
