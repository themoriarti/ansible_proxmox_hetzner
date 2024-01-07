#!/bin/bash

apt update && apt upgrade --yes



rm /etc/default/zfs

echo "wget -qO- https://raw.githubusercontent.com/terem42/zfs-hetzner-vm/master/hetzner-debian12-zfs-setup.sh | bash -"

