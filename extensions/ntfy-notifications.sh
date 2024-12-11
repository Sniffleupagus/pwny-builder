#
# send notifications via ntfy.sh at different points along the build
#
NTFY_SERVER=${NTFY_SERVER:-"ntfy.sh"}
NTFY_TOPIC=${NTFY_TOPIC:-""}

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

function post_family_config__ntfy_send() {
    if [ -n "${NTFY_TOPIC}" ]; then
	pwd | ntfy_send "Starting ${BOARD}" default partying_face
    else
	echo "${BOARD} $(uname -a)" | NTFY_TOPIC=pwny_builder ntfy_send "New builder" 5 dart
    fi
}

function pre_customize_image__ntfy_send() {
    ls -latr ${SDCARD}/tmp | ntfy_send "You like a ${BOARD} on yo ${BOARD}?" 2 toolbox
}

function post_customize_image__ntfy_send() {
    ls -a ${SDCARD}/{etc,home}/pwnagotchi | ntfy_send "Now you got a ${BOARD} on yo ${BOARD}!" 2 vulcan_salute
}

function post_create_partitions__ntfy_send() {
    sfdisk -l ${SDCARD}.raw | ntfy_send "${BOARD} Partitions complete" 2 card_index_dividers
}

function run_after_build__ntfy_send() {
    ls -ltr output/images | tail -5 | ntfy_send "${BOARD} Completed" default checkered_flag
}

