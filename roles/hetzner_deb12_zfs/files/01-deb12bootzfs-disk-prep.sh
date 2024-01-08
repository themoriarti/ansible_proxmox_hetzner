#!/bin/bash

# Format disks and create zpools and mount

set -o errexit
set -o pipefail
set -o nounset

# Load variables and shared functions
source config.sh

#################### MAIN ################################
export LC_ALL=en_US.UTF-8
export NCURSES_NO_UTF8_ACS=1

check_prerequisites

determine_kernel_variant

echo "======= update path and test zfs installed =========="

  apt update
  export PATH=$PATH:/usr/sbin
  zfs --version

echo "======= partitioning the disk =========="

  if [[ $v_free_tail_space -eq 0 ]]; then
    tail_space_parameter=0
  else
    tail_space_parameter="-${v_free_tail_space}G"
  fi

  for selected_disk in "${v_selected_disks[@]}"; do
    wipefs --all --force "$selected_disk"
    sgdisk -a1 -n1:24K:+1000K            -t1:EF02 "$selected_disk"
    sgdisk -n2:0:+2G                   -t2:BF01 "$selected_disk" # Boot pool
    sgdisk -n3:0:"$tail_space_parameter" -t3:BF01 "$selected_disk" # Root pool
  done

  udevadm settle

echo "======= create zfs pools and datasets =========="

  rpool_disks_partitions=()
  bpool_disks_partitions=()

  for selected_disk in "${v_selected_disks[@]}"; do
    rpool_disks_partitions+=("${selected_disk}-part3")
    bpool_disks_partitions+=("${selected_disk}-part2")
  done

  pools_mirror_option=mirror

zpool create \
  -o ashift=12  \
  -o compatibility=grub2 \
  -o autotrim=on \
  -o cachefile=/etc/zpool.cache \
  -O compression=lz4 \
  -O canmount=off \
  -O devices=off \
  -O normalization=formD \
  -O relatime=on \
  -O acltype=posixacl \
  -O xattr=sa \
  -O mountpoint=/boot -R $c_zfs_mount_dir -f \
  $v_bpool_name $v_pools_mirror_option "${bpool_disks_partitions[@]}"


echo -n "$v_passphrase" | zpool create \
  -o ashift=12 \
  -o cachefile=/etc/zpool.cache \
  -O acltype=posixacl \
  -O compression=lz4 \
  -O dnodesize=auto \
  -O relatime=on \
  -O xattr=sa \
  -O normalization=formD \
  -O mountpoint=/ -R $c_zfs_mount_dir -f \
  $v_rpool_name $v_pools_mirror_option "${rpool_disks_partitions[@]}"

zfs create -o canmount=off -o mountpoint=none "$v_rpool_name/ROOT"
zfs create -o canmount=off -o mountpoint=none "$v_bpool_name/BOOT"

zfs create -o canmount=noauto -o mountpoint=/ "$v_rpool_name/ROOT/debian"
zfs mount "$v_rpool_name/ROOT/debian"

zfs create -o canmount=noauto -o mountpoint=/boot "$v_bpool_name/BOOT/debian"
zfs mount "$v_bpool_name/BOOT/debian"

zfs create                                 "$v_rpool_name/home"
#zfs create -o mountpoint=/root             "$v_rpool_name/home/root"
zfs create -o canmount=off                 "$v_rpool_name/var"
zfs create                                 "$v_rpool_name/var/log"
zfs create                                 "$v_rpool_name/var/spool"
zfs create -o com.sun:auto-snapshot=false  "$v_rpool_name/var/cache"
zfs create -o com.sun:auto-snapshot=false  "$v_rpool_name/var/tmp"
chmod 1777 "$c_zfs_mount_dir/var/tmp"
zfs create                                 "$v_rpool_name/srv"
zfs create -o canmount=off                 "$v_rpool_name/usr"
zfs create                                 "$v_rpool_name/usr/local"
zfs create                                 "$v_rpool_name/var/mail"

zfs create -o com.sun:auto-snapshot=false -o canmount=on -o mountpoint=/tmp "$v_rpool_name/tmp"
chmod 1777 "$c_zfs_mount_dir/tmp"

if [[ $v_swap_size -gt 0 ]]; then
  zfs create \
    -V "${v_swap_size}G" -b "$(getconf PAGESIZE)" \
    -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false \
    "$v_rpool_name/swap"

  udevadm settle

  mkswap -f "/dev/zvol/$v_rpool_name/swap"
fi
