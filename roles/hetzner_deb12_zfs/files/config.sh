#!/bin/bash

# Shared variables for the deb12bootzfs scripts

export TMPDIR=/tmp

# Variables
v_bpool_name=bpool
v_bpool_tweaks="-o ashift=12 -O compression=lz4"
v_rpool_name=rpool
v_rpool_tweaks="-o ashift=12 -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O relatime=on -O xattr=sa -O normalization=formD"
v_swap_size=32               # integer
v_free_tail_space=0          # integer
v_hostname=prox02.84lmr.com
v_kernel_variant=
v_zfs_arc_max_mb=64
v_root_password=a3qmon
v_encrypt_rpool=0             # 0=false, 1=true
v_passphrase=
v_zfs_experimental=0
v_suitable_disks=()
v_selected_disks=("/dev/disk/by-id/nvme-SAMSUNG_MZQLB960HAJR-00007_S437NA0N701606" "/dev/disk/by-id/nvme-SAMSUNG_MZQLB960HAJR-00007_S437NA0N701616")
v_pools_mirror_option=mirror


# Constants
c_deb_packages_repo=https://mirror.hetzner.com/debian/packages
c_deb_security_repo=https://mirror.hetzner.com/debian/security
c_default_zfs_arc_max_mb=64
c_default_bpool_tweaks="-o ashift=12 -O compression=lz4"
c_default_rpool_tweaks="-o ashift=12 -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O relatime=on -O xattr=sa -O normalization=formD"
c_default_hostname=prox02.84lmr.com
c_zfs_mount_dir=/mnt
c_log_dir=$(dirname "$(mktemp)")/zfs-hetzner-vm
c_install_log=$c_log_dir/install.log
c_lsb_release_log=$c_log_dir/lsb_release.log
c_disks_log=$c_log_dir/disks.log

# Functions

function store_os_distro_information {
  lsb_release --all > "$c_lsb_release_log"
}

function check_prerequisites {
  if [[ $(id -u) -ne 0 ]]; then
    echo 'This script must be run with administrative privileges!'
    exit 1
  fi
  if [[ ! -r /root/.ssh/authorized_keys ]]; then
    echo "SSH pubkey file is absent, please add it to the rescue system setting, then reboot into rescue system and run the script"
    exit 1
  fi
  if ! dpkg-query --showformat="\${Status}" -W dialog 2> /dev/null | grep -q "install ok installed"; then
    apt install --yes dialog
  fi
}

function initial_load_debian_zed_cache {
  chroot_execute "mkdir /etc/zfs/zfs-list.cache"
  chroot_execute "touch /etc/zfs/zfs-list.cache/$v_rpool_name"
  chroot_execute "ln -sf /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d/"

  chroot_execute "zed -F &"

  local success=0

  if [[ ! -e "$c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name" ]] || [[ -e "$c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name" && (( $(find "$c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name" -type f -printf '%s' 2> /dev/null) == 0 )) ]]; then  
    chroot_execute "zfs set canmount=noauto $v_rpool_name"

    SECONDS=0

    while (( SECONDS++ <= 120 )); do
      if [[ -e "$c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name" ]] && (( $(find "$c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name" -type f -printf '%s' 2> /dev/null) > 0 )); then
        success=1
        break
      else
        sleep 1
      fi
    done
  else
    success=1
  fi

  if (( success != 1 )); then
    echo "Fatal zed daemon error: the ZFS cache hasn't been updated by ZED!"
    exit 1
  fi

  chroot_execute "pkill zed"

  sed -Ei "s|/$c_zfs_mount_dir/?|/|g" "$c_zfs_mount_dir/etc/zfs/zfs-list.cache/$v_rpool_name"
}

function determine_kernel_variant {
  if dmidecode | grep -q vServer; then
    v_kernel_variant="-cloud"
  fi
}

function chroot_execute {
  chroot $c_zfs_mount_dir bash -c "$1"
}

function unmount_and_export_fs {
  for virtual_fs_dir in dev sys proc; do
    umount --recursive --force --lazy "$c_zfs_mount_dir/$virtual_fs_dir"
  done

  local max_unmount_wait=5
  echo -n "Waiting for virtual filesystems to unmount "

  SECONDS=0

  for virtual_fs_dir in dev sys proc; do
    while mountpoint -q "$c_zfs_mount_dir/$virtual_fs_dir" && [[ $SECONDS -lt $max_unmount_wait ]]; do
      sleep 0.5
      echo -n .
    done
  done

  echo

  for virtual_fs_dir in dev sys proc; do
    if mountpoint -q "$c_zfs_mount_dir/$virtual_fs_dir"; then
      echo "Re-issuing umount for $c_zfs_mount_dir/$virtual_fs_dir"
      umount --recursive --force --lazy "$c_zfs_mount_dir/$virtual_fs_dir"
    fi
  done

  SECONDS=0
  zpools_exported=99
  echo "===========exporting zfs pools============="
  set +e
  while (( zpools_exported == 99 )) && (( SECONDS++ <= 60 )); do    
    if zpool export -a 2> /dev/null; then
      zpools_exported=1
      echo "all zfs pools were succesfully exported"
      break;
    else
      sleep 1
     fi
  done
  set -e
  if (( zpools_exported != 1 )); then
    echo "failed to export zfs pools"
    exit 1
  fi
}