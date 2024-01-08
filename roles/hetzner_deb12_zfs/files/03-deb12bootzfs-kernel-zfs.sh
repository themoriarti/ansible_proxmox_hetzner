#!/bin/bash

# Install kernel and zfs

set -o errexit
set -o pipefail
set -o nounset

# Load variables and shared functions
source config.sh

#################### MAIN ################################
export LC_ALL=en_US.UTF-8
export NCURSES_NO_UTF8_ACS=1

echo "======= installing latest kernel============="
# linux-headers-generic linux-image-generic
chroot_execute "apt install --yes linux-image${v_kernel_variant}-amd64 linux-headers${v_kernel_variant}-amd64 dpkg-dev"

echo "======= installing aux packages =========="
chroot_execute "apt install --yes man wget curl software-properties-common nano htop gnupg"

echo "======= installing zfs packages =========="
chroot_execute 'echo "zfs-dkms zfs-dkms/note-incompatible-licenses note true" | debconf-set-selections'

chroot_execute "apt install -t bookworm-backports --yes zfs-initramfs zfs-dkms zfsutils-linux"
chroot_execute 'cat << DKMS > /etc/dkms/zfs.conf
# override for /usr/src/zfs-*/dkms.conf:
# always rebuild initrd when zfs module has been changed
# (either by a ZFS update or a new kernel version)
REMAKE_INITRD="yes"
DKMS'

chroot_execute 'cat << CONF > /etc/apt/preferences.d/90_zfs
Package: src:zfs-linux
Pin: release n=bookworm-backports
Pin-Priority: 990
CONF'

echo "======= setting up zfs cache =========="
cp /etc/zpool.cache "$c_zfs_mount_dir/etc/zfs/zpool.cache"

echo "========setting up zfs module parameters========"
chroot_execute "echo options zfs zfs_arc_max=$((v_zfs_arc_max_mb * 1024 * 1024)) >> /etc/modprobe.d/zfs.conf"
