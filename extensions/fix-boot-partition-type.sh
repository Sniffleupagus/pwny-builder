#
# This extension will change the bootfs partition type from "ef" (Linux Extended) to
#   "0b" (Win95 FAT)

function post_create_partitions__fix_bootfs_fat_type() {
    echo "Fixing the boot partition"
    local next=1
    if [[ $UEFISIZE -gt 0 ]]; then
        local uefipart=$((next++))
    fi
    
    if [[ $BOOTSIZE != "0" && (-n $BOOTFS_TYPE || $ROOTFS_TYPE != ext4 || $BOOTPART_REQUIRED == yes) ]]; then
	local bootpart=$((next++))
	local boottype=$(sfdisk --part-type ${SDCARD}.raw ${bootpart})
	echo "BootFS part is ${bootpart} ${boottype}"
	if [[ "$boottype" != 'b' ]]; then
	    echo "--> Changing bootfs type from '${boottype}' to 'b'"
	    sfdisk --part-type ${SDCARD}.raw ${bootpart} 'b'
	fi
    fi
}
