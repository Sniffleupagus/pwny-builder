#
# send notifications via ntfy.sh at different points along the build
#

function ntfy_send() {
    msg=${1:-"Nothing happened."}
    title=${2:-''}
    priority=${3:-'default'}
    tags=${4:-'warning'}
    markdown=${5:-''}
    topic=${6:-'pwny_builder'}
    
    echo "${msg}" | curl -s -H "t:${title}"  -H "p:${priority}" -H "ta: ${tags}" -d @-  ntfy.sh/${topic}
}

function post_family_config__ntfy_send() {
    ntfy_send "Family configured. Let's go!" "PwnyBuild ${BOARD}" default partying_face
}

function pre_customize_image__ntfy_send() {
    ntfy_send "Beginning pwnagotchi customzation" "PwnyBuild ${BOARD}" default toolbox
}

function post_customize_image__ntfy_send() {
    ntfy_send "Finished pwnagotchi customization" "PwnyBuild ${BOARD}" default vulcan_salute
}

function post_create_partitions__ntfy_send() {
    ntfy_send "$(sfdisk -l ${SDCARD}.raw)" "${BOARD} Partitions complete" default card_index_dividers
}

function run_after_build__ntfy_send() {
    ntfy_send "Build completed at $(date)" "PwnyBuild ${BOARD}" default checkered_flag
}

