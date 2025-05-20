#!/bin/bash -e

echo "*=*=---*> Torch and Torchvision"
apt-get install -y python3-pip
pwd

pushd /tmp
ls -l

# uninstall system versions
#pip3 uninstall torch torchvision --break-system-packages

source ~pwnagotchi/.venv/bin/activate

if pip3 download --no-deps torchvision ; then
    echo "* Torch can be downloaded, so not building. Whew!"
    exit
else
    echo "*    No precompiled torchvision available."
    echo "+    BUILDING from source"
    echo "!    This will take a while"
fi
popd

if [ -f /tmp/torch-packages ]; then
    echo "=-=-=- Installing torch apt dependencies -=-=-="
    apt-get -y install $(cat /tmp/torch-packages)
fi

cd /usr/local/src

if [ ! -d pytorch ]; then
    git clone --branch v2.1.2 https://github.com/pytorch/pytorch.git --recursive
else
    echo "Already dun git it"
fi

pushd pytorch

if [ -f dist/torch-*.whl ]; then
    ls -l dist/torch-*.whl
else

    export QEMU_UNAME=6.1.0-rpi7-rpi-v6


    uname -a
    cmake --version
    python3 --version
    which pip
    which pip3

    ls -l /lib/modules


    pip3 install -r requirements.txt #--break-system-packages

    export USE_CUDA=OFF
    export USE_DISTRIBUTED=OFF
    export USE_MKLDNN=OFF
    export BUILD_TEST=OFF
    export BUILD_BINARY=OFF
    export MAX_JOBS=4
    
    unset USE_QEMU


    if [ $(uname -m) = "armv6l" ]; then
	export USE_NNPACK=OFF
	export USE_QNNPACK=OFF
	export USE_PYTORCH_QNNPACK=OFF
	export USE_XNNPACK=OFF
	export USE_NUMA=OFF
	export USE_SYSTEM_CPUINFO=ON
	export USE_SYSTEM_SLEEF=ON
	export BUILD_CUSTOM_PROTOBUF=OFF

	# patch /usr/include/cpuinfo.h for a missing check - GROSS, but whatever
	if ! grep "cpuinfo_has_arm_bf16" /usr/include/cpuinfo.h ; then
	    sudo patch /usr/include/cpuinfo.h <<EOP
--- /tmp/cpuinfo.h	2023-07-09 11:36:13.993161372 -0700
+++ cpuinfo.h	2023-07-09 11:35:47.923343576 -0700
@@ -1468,6 +1468,11 @@
 	extern struct cpuinfo_arm_isa cpuinfo_isa;
 #endif
 
+/* needed for pytorch build */
+static inline bool cpuinfo_has_arm_bf16(void) {
+	return false;
+}
+
 static inline bool cpuinfo_has_arm_thumb(void) {
 	#if CPUINFO_ARCH_ARM
 		return cpuinfo_isa.thumb;
EOP

	fi
    fi

    time python3 setup.py bdist_wheel
fi

figlet install torch
pip3 install dist/torch-*.whl #--break-system-packages

popd

# install torchvision
if [ ! -d vision ]; then
    git clone --branch v0.16.0 --depth=1 https://github.com/pytorch/vision
fi

pushd vision
export MAX_JOBS=10

if [ ! -f dist/torchvision-*.whl ]; then
    time python3 setup.py bdist_wheel
else
    ls -l dist/
fi

pip3 install dist/torchvision-*.whl

popd

deactivate
