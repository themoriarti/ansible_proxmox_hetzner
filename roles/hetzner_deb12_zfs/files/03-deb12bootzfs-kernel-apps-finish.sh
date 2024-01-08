#!/bin/bash

# Install kernel, apps, logins, zed and finalise

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