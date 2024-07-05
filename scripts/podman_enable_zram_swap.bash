#!/usr/bin/env bash

# This script activates zram backed swap for memory compression

# figure out total RAM in kilobytes
vm_ram=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)
# load zram kernel module
modprobe zram
# create compressed ramdisk, sized 75% of the RAM
echo $((vm_ram*768)) > /sys/block/zram0/disksize
# create anc activate swap
mkswap /dev/zram0
swapon /dev/zram0
