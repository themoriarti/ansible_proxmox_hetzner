#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

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

#################### MAIN ################################
export LC_ALL=en_US.UTF-8
export NCURSES_NO_UTF8_ACS=1

check_prerequisites

#activate_debug

#display_intro_banner

#find_suitable_disks

#select_disks

determine_kernel_variant

clear

echo "===========remove unused kernels in rescue system========="


echo "======= installing zfs on rescue system =========="

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

  encryption_options=()
  rpool_disks_partitions=()
  bpool_disks_partitions=()

  for selected_disk in "${v_selected_disks[@]}"; do
    rpool_disks_partitions+=("${selected_disk}-part3")
    bpool_disks_partitions+=("${selected_disk}-part2")
  done

  pools_mirror_option=mirror

zpool create \
  $v_bpool_tweaks -O canmount=off -O devices=off \
  -o compatibility=grub2 \
  -o autotrim=on \
  -O normalization=formD \
  -O relatime=on \
  -O acltype=posixacl -O xattr=sa \
  -o cachefile=/etc/zpool.cache \
  -O mountpoint=/boot -R $c_zfs_mount_dir -f \
  $v_bpool_name $v_pools_mirror_option "${bpool_disks_partitions[@]}"

echo -n "$v_passphrase" | zpool create \
  $v_rpool_tweaks \
  -o cachefile=/etc/zpool.cache \
  "${encryption_options[@]}" \
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

echo "======= setting up initial system packages =========="
debootstrap --arch=amd64 bookworm "$c_zfs_mount_dir" "$c_deb_packages_repo"

zfs set devices=off "$v_rpool_name"

echo "======= setting up the network =========="

echo "$v_hostname" > $c_zfs_mount_dir/etc/hostname

cat > "$c_zfs_mount_dir/etc/hosts" <<CONF
127.0.1.1 ${v_hostname}
127.0.0.1 localhost

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
sed -i 's/# fr_FR.UTF-8/fr_FR.UTF-8/' "$c_zfs_mount_dir/etc/locale.gen"
sed -i 's/# fr_FR.UTF-8/fr_FR.UTF-8/' "$c_zfs_mount_dir/etc/locale.gen"
sed -i 's/# de_AT.UTF-8/de_AT.UTF-8/' "$c_zfs_mount_dir/etc/locale.gen"
sed -i 's/# de_DE.UTF-8/de_DE.UTF-8/' "$c_zfs_mount_dir/etc/locale.gen"

chroot_execute 'cat <<CONF | debconf-set-selections
locales locales/default_environment_locale      select  en_US.UTF-8
keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db     boolean true
keyboard-configuration  keyboard-configuration/variant  select  German
keyboard-configuration  keyboard-configuration/unsupported_layout       boolean true
keyboard-configuration  keyboard-configuration/modelcode        string  pc105
keyboard-configuration  keyboard-configuration/unsupported_config_layout        boolean true
keyboard-configuration  keyboard-configuration/layout   select  German
keyboard-configuration  keyboard-configuration/layoutcode       string  de
keyboard-configuration  keyboard-configuration/optionscode      string
keyboard-configuration  keyboard-configuration/toggle   select  No toggling
keyboard-configuration  keyboard-configuration/xkb-keymap       select  de
keyboard-configuration  keyboard-configuration/switch   select  No temporary switch
keyboard-configuration  keyboard-configuration/unsupported_config_options       boolean true
keyboard-configuration  keyboard-configuration/ctrl_alt_bksp    boolean false
keyboard-configuration  keyboard-configuration/variantcode      string
keyboard-configuration  keyboard-configuration/model    select  Generic 105-key PC (intl.)
keyboard-configuration  keyboard-configuration/altgr    select  The default for the keyboard layout
keyboard-configuration  keyboard-configuration/compose  select  No compose key
keyboard-configuration  keyboard-configuration/unsupported_options      boolean true
console-setup   console-setup/fontsize-fb47     select  8x16
console-setup   console-setup/store_defaults_in_debconf_db      boolean true
console-setup   console-setup/codeset47 select  # Latin1 and Latin5 - western Europe and Turkic languages
console-setup   console-setup/fontface47        select  Fixed
console-setup   console-setup/fontsize  string  8x16
console-setup   console-setup/charmap47 select  UTF-8
console-setup   console-setup/fontsize-text47   select  8x16
console-setup   console-setup/codesetcode       string  Lat15
tzdata tzdata/Areas select Europe
tzdata tzdata/Zones/Europe select Vienna
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

echo "======= installing OpenSSH and network tooling =========="
chroot_execute "apt install --yes openssh-server net-tools"

echo "======= setup OpenSSH  =========="
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' "$c_zfs_mount_dir/etc/ssh/sshd_config"
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' "$c_zfs_mount_dir/etc/ssh/sshd_config"
chroot_execute "rm /etc/ssh/ssh_host_*"
chroot_execute "dpkg-reconfigure openssh-server -f noninteractive"

echo "======= set root password =========="
chroot_execute "echo root:$(printf "%q" "$v_root_password") | chpasswd"

echo "======= setting up zfs cache =========="
cp /etc/zpool.cache "$c_zfs_mount_dir/etc/zfs/zpool.cache"

echo "========setting up zfs module parameters========"
chroot_execute "echo options zfs zfs_arc_max=$((v_zfs_arc_max_mb * 1024 * 1024)) >> /etc/modprobe.d/zfs.conf"

echo "======= setting up grub =========="
chroot_execute "echo 'grub-pc grub-pc/install_devices_empty   boolean true' | debconf-set-selections"
chroot_execute "DEBIAN_FRONTEND=noninteractive apt install --yes grub-legacy"
chroot_execute "DEBIAN_FRONTEND=noninteractive apt install --yes grub-pc"
for disk in ${v_selected_disks[@]}; do
  chroot_execute "grub-install --recheck $disk"
done

chroot_execute "sed -i 's/#GRUB_TERMINAL=console/GRUB_TERMINAL=console/g' /etc/default/grub"
chroot_execute "sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"net.ifnames=0\"|' /etc/default/grub"
chroot_execute "sed -i 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"root=ZFS=$v_rpool_name/ROOT/debian\"|g' /etc/default/grub"

chroot_execute "sed -i 's/quiet//g' /etc/default/grub"
chroot_execute "sed -i 's/splash//g' /etc/default/grub"
chroot_execute "echo 'GRUB_DISABLE_OS_PROBER=true'   >> /etc/default/grub"

for ((i = 1; i < ${#v_selected_disks[@]}; i++)); do
  dd if="${v_selected_disks[0]}-part1" of="${v_selected_disks[i]}-part1"
done

echo "============setup root prompt============"
cat > "$c_zfs_mount_dir/root/.bashrc" <<CONF
export PS1='\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;32m\]\h \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]'
umask 022
export LS_OPTIONS='--color=auto -h'
eval "\$(dircolors)"
CONF

echo "========= add root pubkey for login via SSH"
mkdir -p "$c_zfs_mount_dir/root/.ssh/"
cp /root/.ssh/authorized_keys "$c_zfs_mount_dir/root/.ssh/authorized_keys"

echo "========running packages upgrade and autoremove==========="
chroot_execute "apt upgrade --yes"
chroot_execute "apt purge cryptsetup* --yes"

echo "===========add static route to initramfs via hook to add default routes for Hetzner due to Debian/Ubuntu initramfs DHCP bug ========="
mkdir -p "$c_zfs_mount_dir/usr/share/initramfs-tools/scripts/init-premount"
cat > "$c_zfs_mount_dir/usr/share/initramfs-tools/scripts/init-premount/static-route" <<'CONF'
#!/bin/sh
PREREQ=""
prereqs()
{
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

. /scripts/functions
# Begin real processing below this line

configure_networking

ip route add 172.31.1.1/255.255.255.255 dev eth0
ip route add default via 172.31.1.1 dev eth0
CONF

chmod 755 "$c_zfs_mount_dir/usr/share/initramfs-tools/scripts/init-premount/static-route"

chmod 755 "$c_zfs_mount_dir/etc/network/interfaces"

echo "======= update initramfs =========="
chroot_execute "update-initramfs -u -k all"

chroot_execute "apt remove cryptsetup* --yes"

echo "======= update grub =========="
chroot_execute "update-grub"

echo "======= setting up zed =========="
if [[ $v_zfs_experimental == "1" ]]; then
  chroot_execute "zfs set canmount=noauto $v_rpool_name"
else
  initial_load_debian_zed_cache
fi

echo "======= setting mountpoints =========="
chroot_execute "zfs set mountpoint=legacy $v_bpool_name/BOOT/debian"
chroot_execute "echo $v_bpool_name/BOOT/debian /boot zfs nodev,relatime,x-systemd.requires=zfs-mount.service,x-systemd.device-timeout=10 0 0 > /etc/fstab"

chroot_execute "zfs set mountpoint=legacy $v_rpool_name/var/log"
chroot_execute "echo $v_rpool_name/var/log /var/log zfs nodev,relatime 0 0 >> /etc/fstab"
chroot_execute "zfs set mountpoint=legacy $v_rpool_name/var/spool"
chroot_execute "echo $v_rpool_name/var/spool /var/spool zfs nodev,relatime 0 0 >> /etc/fstab"
chroot_execute "zfs set mountpoint=legacy $v_rpool_name/var/tmp"
chroot_execute "echo $v_rpool_name/var/tmp /var/tmp zfs nodev,relatime 0 0 >> /etc/fstab"
chroot_execute "zfs set mountpoint=legacy $v_rpool_name/tmp"
chroot_execute "echo $v_rpool_name/tmp /tmp zfs nodev,relatime 0 0 >> /etc/fstab"

echo "========= add swap, if defined"
if [[ $v_swap_size -gt 0 ]]; then
  chroot_execute "echo /dev/zvol/$v_rpool_name/swap none swap discard 0 0 >> /etc/fstab"
fi

chroot_execute "echo RESUME=none > /etc/initramfs-tools/conf.d/resume"

echo "======= unmounting filesystems and zfs pools =========="
unmount_and_export_fs

echo "======== setup complete, rebooting ==============="
reboot