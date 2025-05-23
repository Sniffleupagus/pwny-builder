#!/bin/bash -e

export PWNY_BUILD_ARTIFACTS="/root/artifacts/${PI_GEN}/${ARCH}/${RELEASE}/${IMG_NAME}"
export OVERLAY_DIR=${OVERLAY_DIR:-/root/overlay}

save_pwny_artifact () {
    file=$1
    dir=$2
    fname=$(basename ${file})
    if [ -f ${PWNY_BUILD_ARTIFACTS}/$dir/$fname ]; then
	rm ${PWNY_BUILD_ARTIFACTS}/$dir/$fname
    fi
    
    echo "Saving artifact ${file} to ${dir}"
    mkdir -p ${PWNY_BUILD_ARTIFACTS}/${dir}
    cp ${file} ${PWNY_BUILD_ARTIFACTS}/${dir}
}

restore_pwny_artifacts () {
    if pushd "${PWNY_BUILD_ARTIFACTS}/$1"; then
	tar -cf - . | tar -C / -xvf -
	popd
	return 0
    fi
    return 1
}
