#!/bin/bash -e

# free up space by removing unnecessary things

if [ ! "${NO_CLEANUP}" ]; then
    echo "- Removing unnecessary packages"
    apt -y remove binutils-arm-none-eabi gcc-arm-none-eabi  # for nexmon firmware
    apt -y autoremove
    echo "- Removing golang"
    rm -rf /usr/local/go      # only needed to build bettercap and pwngrid
    rm -rf /root/go
    echo "- Removing caches"
    rm -rf /root/.cache
    rm -rf /var/cache/apt
    echo "- Removing source code from /usr/local/src"
    rm -rf /usr/local/src/*
fi
