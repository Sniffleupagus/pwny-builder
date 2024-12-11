#
# send notifications via ntfy.sh at different points along the build
#
NTFY_SERVER=${NTFY_SERVER:-"ntfy.sh"}
NTFY_TOPIC=${NTFY_TOPIC:-""}


# list of files we are interested in
export PWNY_ARTIFACT_DEST=${PWNY_ARTIFACT_DEST:-"userpatches/overlay/pwnagotchi/files/${BOARD}"}
export PWNY_ARTIFACT_ROOT=/tmp/pwny_parts
			    
function ntfy_send() {
    title=${1:-''}
    priority=${2:-'default'}
    tags=${3:-'warning'}
    markdown=${4:-''}

    if [ -n "${NTFY_TOPIC}" ]; then
	cat | curl -s -H "t:${title}"  -H "p:${priority}" -H "ta: ${tags}" -d @-  ${NTFY_SERVER}/${NTFY_TOPIC}
    else
	cat >/dev/null
    fi
}

function pre_customize_image__restore_prior_artifacts() {
    if [ -d ${PWNY_ARTIFACT_DEST} ]; then
	pushd ${PWNY_ARTIFACT_DEST}
	for f in *; do
	    echo $f
	    cp -rpf $f ${SDCARD}/
	done 2>&1 | ntfy_send "Installed Old Artifacts" default cd
	popd
    fi
}

function post_customize_image__backup_new_artifacts() {
    pushd ${SDCARD}/${PWNY_ARTIFACT_ROOT}
    find . -type f
    find . -type f | ntfy_send "New artifacts" default package
    popd

    if [ -n "$(ls)" ]; then
	mkdir -p ${PWNY_ARTIFACT_DEST}
	for f in  ${SDCARD}/${PWNY_ARTIFACT_ROOT}/* ; do
	    cp -rp $f ${PWNY_ARTIFACT_DEST}/$(basename f) || true
	done
    fi

    if ls ${SDCARD}/tmp/pwnagotchi.*; then
	cp ${SDCARD}/tmp/pwnagotchi.* /tmp
    fi
}
