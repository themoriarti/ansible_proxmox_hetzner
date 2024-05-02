#!/bin/bash

# For Proxmox OS
first_os_device="/dev/$(lsblk | grep G | awk '{print $1}' | tail -2 | head -1)"
second_os_device="/dev/$(lsblk | grep G | awk '{print $1}' | tail -2 | tail -1)"

# For data tank (big disks more then 1T)
first_tank_device="/dev/$(lsblk | grep T | awk '{print $1}' | tail -2 | head -1)"
second_tank_device="/dev/$(lsblk | grep T | awk '{print $1}' | tail -2 | tail -1)"

# OS devices find the by-id symlink
first_os_id=$(find /dev/disk/by-id/ -type l -exec sh -c 'echo "$(readlink -f {}) $(basename {})"' \; | grep "^$first_os_device" | awk '{print $2}' | grep ata)
second_os_id=$(find /dev/disk/by-id/ -type l -exec sh -c 'echo "$(readlink -f {}) $(basename {})"' \; | grep "^$second_os_device" | awk '{print $2}' | grep ata)

# Tank devices find the by-id symlink
first_tank_id=$(find /dev/disk/by-id/ -type l -exec sh -c 'echo "$(readlink -f {}) $(basename {})"' \; | grep "^$first_tank_device" | awk '{print $2}' | grep ata)
second_tank_id=$(find /dev/disk/by-id/ -type l -exec sh -c 'echo "$(readlink -f {}) $(basename {})"' \; | grep "^$second_tank_device" | awk '{print $2}' | grep ata)

# Create the new zfs_root_devices array
zfs_root_devices=(
    "/dev/disk/by-id/$first_os_id"
    "/dev/disk/by-id/$second_os_id"
)

# Create the new zfs_tank_devices array
zfs_tank_devices=(
    "/dev/disk/by-id/$first_tank_id"
    "/dev/disk/by-id/$second_tank_id"
)

# Output the new array
echo "zfs_root_devices: [\"${zfs_root_devices[0]}\", \"${zfs_root_devices[1]}\"]"
echo "zfs_tank_devices: [\"${zfs_tank_devices[0]}\", \"${zfs_tank_devices[1]}\"]"
