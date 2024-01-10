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

echo "======= setting up initial system packages =========="
debootstrap --arch=amd64 bookworm "$c_zfs_mount_dir" "$c_deb_packages_repo"

zfs set devices=off "$v_rpool_name"

echo "======= setting up the network =========="

echo "$v_hostname" > $c_zfs_mount_dir/etc/hostname

cat > "$c_zfs_mount_dir/etc/hosts" <<CONF
127.0.1.1 ${v_hostname}
127.0.0.1 localhost
${v_ip_address} ${v_hostname} ${v_hostname_alias}
# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
CONF

ip6addr_prefix=$(ip -6 a s | grep -E "inet6.+global" | sed -nE 's/.+inet6\s(([0-9a-z]{1,4}:){4,4}).+/\1/p' | head -n 1)

cat <<CONF > "$c_zfs_mount_dir/etc/systemd/network/10-eth0.network"
[Match]
Name=eth0

[Network]
DHCP=ipv4
Address=${ip6addr_prefix}:1/64
Gateway=fe80::1
CONF
chroot_execute "systemctl enable systemd-networkd.service"

echo "======= preparing the jail for chroot =========="
for virtual_fs_dir in proc sys dev; do
  mount --rbind "/$virtual_fs_dir" "$c_zfs_mount_dir/$virtual_fs_dir"
done

echo "======= setting apt repos =========="
cat > "$c_zfs_mount_dir/etc/apt/sources.list" <<CONF
deb $c_deb_packages_repo bookworm main contrib non-free non-free-firmware
deb $c_deb_packages_repo bookworm-updates main contrib non-free non-free-firmware
deb $c_deb_security_repo bookworm-security main contrib non-free non-free-firmware
deb $c_deb_packages_repo bookworm-backports main contrib non-free non-free-firmware
CONF

chroot_execute "apt update"

echo "======= setting locale, console and language =========="
chroot_execute "apt install --yes -qq locales debconf-i18n apt-utils"
sed -i 's/# en_US.UTF-8/en_US.UTF-8/' "$c_zfs_mount_dir/etc/locale.gen"
sed -i 's/# en_GB.UTF-8/en_GB.UTF-8/' "$c_zfs_mount_dir/etc/locale.gen"

chroot_execute 'cat <<CONF | debconf-set-selections
locales locales/default_environment_locale      select  en_US.UTF-8
# keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db     boolean true
# keyboard-configuration  keyboard-configuration/variant  select  German
# keyboard-configuration  keyboard-configuration/unsupported_layout       boolean true
# keyboard-configuration  keyboard-configuration/modelcode        string  pc105
# keyboard-configuration  keyboard-configuration/unsupported_config_layout        boolean true
# keyboard-configuration  keyboard-configuration/layout   select  German
# keyboard-configuration  keyboard-configuration/layoutcode       string  de
# keyboard-configuration  keyboard-configuration/optionscode      string
# keyboard-configuration  keyboard-configuration/toggle   select  No toggling
# keyboard-configuration  keyboard-configuration/xkb-keymap       select  de
# keyboard-configuration  keyboard-configuration/switch   select  No temporary switch
# keyboard-configuration  keyboard-configuration/unsupported_config_options       boolean true
# keyboard-configuration  keyboard-configuration/ctrl_alt_bksp    boolean false
# keyboard-configuration  keyboard-configuration/variantcode      string
# keyboard-configuration  keyboard-configuration/model    select  Generic 105-key PC (intl.)
# keyboard-configuration  keyboard-configuration/altgr    select  The default for the keyboard layout
# keyboard-configuration  keyboard-configuration/compose  select  No compose key
# keyboard-configuration  keyboard-configuration/unsupported_options      boolean true
# console-setup   console-setup/fontsize-fb47     select  8x16
# console-setup   console-setup/store_defaults_in_debconf_db      boolean true
# console-setup   console-setup/codeset47 select  # Latin1 and Latin5 - western Europe and Turkic languages
# console-setup   console-setup/fontface47        select  Fixed
# console-setup   console-setup/fontsize  string  8x16
# console-setup   console-setup/charmap47 select  UTF-8
# console-setup   console-setup/fontsize-text47   select  8x16
# console-setup   console-setup/codesetcode       string  Lat15
tzdata tzdata/Areas select Europe
tzdata tzdata/Zones/Europe select London
grub-pc grub-pc/install_devices_empty   boolean true
CONF'

chroot_execute "dpkg-reconfigure locales -f noninteractive"
echo -e "LC_ALL=en_US.UTF-8\nLANG=en_US.UTF-8\n" >> "$c_zfs_mount_dir/etc/environment"
chroot_execute "apt install -qq --yes keyboard-configuration console-setup"
chroot_execute "dpkg-reconfigure keyboard-configuration -f noninteractive"
chroot_execute "dpkg-reconfigure console-setup -f noninteractive"
chroot_execute "setupcon"

chroot_execute "rm -f /etc/localtime /etc/timezone"
chroot_execute "dpkg-reconfigure tzdata -f noninteractive"
