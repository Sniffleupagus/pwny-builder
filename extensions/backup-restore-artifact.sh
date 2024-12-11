#
# send notifications via ntfy.sh at different points along the build
#
NTFY_SERVER=${NTFY_SERVER:-"ntfy.sh"}
NTFY_TOPIC=${NTFY_TOPIC:-""}


# list of files we are interested in
export PWNY_ARTIFACT_DEST=${PWNY_ARTIFACT_DEST:-"overlay/pwnagotchi/files/${BOARD}"}
export PWNY_ARTIFACT_ROOT=${SDCARD}/tmp/pwny_parts
			    
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
    mkdir -p ${PWNY_ARTIFACT_ROOT}/${BOARD}
    mkdir -p ${PWNY_ARTIFACT_DEST}
    ls -l ${PWNY_ARTIFACT_DEST} 2>&1 | ntfy_send "Set up temporary ${BOARD}" default partying_face

    pushd ${PWNY_ARTIFACT_DEST}
    for f in *; do
	echo $f
	cp -rpf $f /
    done 2>&1 | ntfy_send "Installed Old Artifacts" default cd

    cp ${SDCARD}/tmp/pwnagotchi.* /tmp

}

function post_customize_image__backup_new_artifacts() {
    pushd ${PWNY_ARTIFACT_ROOT}
    ls -ltrR
    ls -ltrR | ntfy_send "New artifacts" default package
    if [ -n "$(ls)" ]; then
	mkdir -p ${PWNY_ARTIFACT_DEST}
	cp -rp * ${PWNY_ARTIFACT_DEST}/
    fi
    
}



