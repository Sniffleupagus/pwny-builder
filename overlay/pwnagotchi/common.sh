#!/bin/bash -e

export PWNY_BUILD_ARTIFACTS=${PWNY_BUILD_ARTIFACTS:-"/root/artifacts/${PI_GEN}/${ARCH}/${RELEASE}/${IMG_NAME}"}
export OVERLAY_DIR=${OVERLAY_DIR:-"/root/overlay/pwnagotchi"}

case "${PI_GEN}" in
    "pi-gen")
	export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/${ARCH}/${RELEASE}/${IMG_NAME}"} ;;
    "armbian-build")
	export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/${BOARD}/${RELEASE}"} ;;
    "deb-img-builder")
	export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/${BOARD}/${HOSTNAME}"} ;;
    *)
	export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/unknown"};;
esac

save_pwny_artifact () {
    file=$1
    dir=$2
    fname=$(basename ${file})
    if [ -f ${PWNY_BUILD_ARTIFACTS}/$dir/$fname ]; then
	rm ${PWNY_BUILD_ARTIFACTS}/$dir/$fname
    fi
    
    echo "+ Saving artifact ${file} to ${dir}"
    mkdir -p ${PWNY_BUILD_ARTIFACTS}/${dir}
    rsync -av ${file} ${PWNY_BUILD_ARTIFACTS}/${dir}
}

restore_pwny_artifacts () {
    echo "Looking for $1"
    case "${PI_GEN}" in
	"pi-gen")
	    export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/${ARCH}/${RELEASE}/${IMG_NAME}"} ;;
	"armbian-build")
	    export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/${BOARD}/${RELEASE}"} ;;
	"deb-img-builder")
	    export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/${BOARD}/${HOSTNAME}"} ;;
	*)
	    export PWNY_ARTIFACT_SUB=${PWNY_ARTIFACT_SUB:-"${PI_GEN}/unknown"};;
    esac
    if pushd ${OVERLAY_DIR}/artifacts/${PWNY_ARTIFACT_SUB}/$1; then
	#tar -cf - . | tar -C / -xvf -
	#cp -rp ./* /
	#rsync -av . /
	for f in $(find . -type f); do
	    echo "Installing ${PWNY_ARTIFACT_SUB}/$f"
	    mkdir -p /$(dirname $f)
	    cp $f /$f
	done
	popd
	return 0
    elif pushd "${PWNY_BUILD_ARTIFACTS}/$1"; then
	#tar -cf - . | tar -C / -xvf -
	#cp -rp ./* /
	for f in $(find . -type f); do
	    echo "Installing ${PWNY_ARTIFACT_SUB}/$f"
	    mkdir -p /$(dirname $f)
	    cp $f /$f
	done
	popd
	return 0
    elif pushd "/tmp/overlay/pwnagotchi/artifacts/${PWNY_ARTIFACT_SUB}/$1"; then
	# armbian-build location
	#tar -cf - . | tar -C / -xvf -
	#cp -rp ./* /
	for f in $(find . -type f); do
	    echo "Installing ${PWNY_ARTIFACT_SUB}/$f"
	    mkdir -p /$(dirname $f)
	    cp $f /$f
	done
	popd
	return 0
    elif pushd "/root/artifacts/${PWNY_ARTIFACT_SUB}/$1"; then
	# debian-image-builder
	#tar -cf - . | tar -C / -xvf -
	#cp -rp ./* /
	for f in $(find . -type f); do
	    echo "Installing ${PWNY_ARTIFACT_SUB}/$f"
	    mkdir -p /$(dirname $f)
	    cp $f /$f
	done
	popd
	return 0
    else
	echo "! no artifact for $1"
	return 1
    fi
    false
    return 1
}

