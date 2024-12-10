#!/bin/bash -e
#
# 03-old-libpcap
#
# Install version 1.9 of libpcap for backwards compatibility

if [ -e /usr/local/lib/libpcap.so ]; then
    echo "= Libpcap already installed"
else
    echo "+ Installing libpcap"
    pushd /usr/local/src
    if [ ! -d libpcap ]; then
	git clone --depth 1  https://github.com/the-tcpdump-group/libpcap.git
    fi
    pushd libpcap
    ./autogen.sh
    ./configure && make -j 10  && make install
    LIBPCAPOK=$?
    popd

    if [ "$LIBPCAPOK" ]; then
	echo "- Removing libpcap source code"
	rm -rf libpcap
	echo "+ Linking libpcap.so.1 to libpcap.so.0.8"
	ln -sf /usr/local/lib/libpcap.so.1 /usr/local/lib/libpcap.so.0.8
    else
	echo "= Not deleting libpcap due to possihble errors"
    fi
    echo
    echo "* Libpcap installed"
fi
