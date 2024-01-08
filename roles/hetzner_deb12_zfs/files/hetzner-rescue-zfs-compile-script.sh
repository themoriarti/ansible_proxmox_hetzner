#!/bin/bash

# Script to compile ZFS on the Hetzner Rescue server
# Source: https://gist.github.com/tijszwinkels/966ec9b38b190bf80c2b2e4cfddf252a

rm -f /usr/local/sbin/fsck.zfs /usr/local/sbin/zdb /usr/local/sbin/zed /usr/local/sbin/zfs /usr/local/sbin/zfs_ids_to_path /usr/local/sbin/zgenhostid /usr/local/sbin/zhack /usr/local/sbin/zinject /usr/local/sbin/zpool /usr/local/sbin/zstream /usr/local/sbin/zstreamdump /usr/local/sbin/ztest >/dev/null 2>&1
cd "$(mktemp -d)" || exit
wget --no-check-certificate "$(curl -Ls https://api.github.com/repos/openzfs/zfs/releases/latest| grep -E "browser_download_url.*\.tar.gz\"$"| cut -d '"' -f 4)"
apt update && apt install libssl-dev uuid-dev zlib1g-dev libblkid-dev -y && tar xfv zfs*.tar.gz && rm zfs*.tar.gz && cd zfs* && ./configure && make -j "$(nproc)" && make install && ldconfig && modprobe zfs
