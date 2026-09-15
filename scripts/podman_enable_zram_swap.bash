#!/usr/bin/env bash

# This script activates zram backed swap for memory compression, with a disk
# backed spillover swap. Both are configured to survive a reboot, and rerunning
# the script leaves an already configured machine untouched.

set -euo pipefail

# figure out total RAM in kilobytes
vm_ram=$(awk '/MemTotal/ { print $2 }' /proc/meminfo)

# compressed ramdisk swap, sized 75% of the RAM and preferred over the disk swap
zram_conf="[zram0]
zram-size = ram * 0.75
swap-priority = 100"
if [[ "$(cat /etc/systemd/zram-generator.conf 2> /dev/null)" != "$zram_conf" ]]; then
  echo "$zram_conf" > /etc/systemd/zram-generator.conf
  systemctl daemon-reload
fi

# spillover swap file on disk, sized 100% of the RAM
swap_file=/var/swap.swp
swap_bytes=$((vm_ram*1024))
if [[ "$(stat -c %s "$swap_file" 2> /dev/null || true)" != "$swap_bytes" ]]; then
  # a failing swapoff has to stop us here, removing a file that is still in use leaks it
  if grep -q "^$swap_file " /proc/swaps; then
    swapoff "$swap_file"
  fi
  rm -f "$swap_file"
  fallocate -l "$swap_bytes" "$swap_file"
fi
grep -qs "^$swap_file " /etc/fstab || echo "$swap_file none swap defaults 0 0" >> /etc/fstab

# activate without waiting for a reboot
if ! grep -q "^$swap_file " /proc/swaps; then
  chmod 0600 "$swap_file"
  mkswap "$swap_file"
  swapon "$swap_file"
fi
# zram cannot be resized while in use, so an already active one waits for a reboot
grep -q '^/dev/zram0 ' /proc/swaps || systemctl start dev-zram0.swap
