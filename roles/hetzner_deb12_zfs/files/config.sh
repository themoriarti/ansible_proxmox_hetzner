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
