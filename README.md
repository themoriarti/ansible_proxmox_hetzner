# First playbook, then fail2ban, then zfs

# Drives to install on (on this server specifically)

<!--
Can't do it by id - installimage script crashes and machine needs cold reboot to rescue!
Need to develop script to get

/dev/sda
/dev/sdd

or which are the two matching this at the time of boot into rescue mode.


480 GB SSD
/dev/disk/by-id/ata-Micron_5200_MTFDDAK480TDC_18191C6C2F89
/dev/disk/by-id/ata-Micron_5200_MTFDDAK480TDC_18451F7E259C



Better seperate out
 - hetzner server install
 - server configuration - e.g. fail2ban, XS optimisations, data drives in zfs mirror etc.
 - proxmox install
 - proxmox configuration
 - use templates for network settings and vmbr etc.

Move as much of XS to ansible as possible

Re-runnimg the script tries to reinstall the proxmox backup and has error

-->

# Commands to create the zfs pool on the larger two disks once proxmox installed

<!--
/sbin/zpool create -o ashift=12 tank mirror /dev/disk/by-id/ata-Micron_5200_MTFDDAK1T9TDC_18191C8F84A4 /dev/disk/by-id/ata-SDLF1CRR-019T-1HA2_A01D3F36
/sbin/zfs set compression=lz4 tank
systemctl enable zfs-import@tank.service
zfs create tank/backups
zfs create tank/isos
zfs create tank/vm-drives
--
# Interface then used to create directories based on these - /etc/pve/storage.cfg

<!--
dir: local
	path /var/lib/vz
	content vztmpl,rootdir,iso,images,backup,snippets
	prune-backups keep-all=1

dir: isos
	path /tank/isos
	content iso,vztmpl
	prune-backups keep-all=1
	shared 0

dir: vm-drives
	path /tank/vm-drives
	content rootdir,images
	prune-backups keep-all=1
	shared 0

dir: backups
	path /tank/backups
	content backup,snippets
	prune-backups keep-all=1
	shared 0
-->

### Proxmox on Hetzner BareMetal with ansible

I made this project just for fun, it allows you to create a proxmox host on Hetzner BareMetal

#### Features

- Debian full crypted ROOT partition
- Install OPNsense as a router. Fake the MAC Address if tge primary Interface and bridged to WAN
- Autoinstall OPNsense (still in progress..)
- Create Backup of OPNsense after setup
- Create Cloud-INIT Images
- Install Proxmox Backup Server

#### Requirements

- `ansible-galaxy collection install community.hrobot` - Need for Hetzner API
- Tested on Hetzner Bare Metal EX43 at FSN1-DC7 - last successfully run 27.02.2023 (storage & opnsense)
- Tested on Hetzner Bare Metal EX43 at HEL1 - last successfully run 19.10.2022 (full)
- Tested on Hetzner Bare Metal Server Auction - CPUIntel Core i9-12900K - 2 x nvme - 02.10.2023 (full)

#### Variables

- `hetzner_pbs_setup` [default: `true` ]: Install Proxmox Backup Server
- `hetzner_pve_autorescue` [default: `true` ]: Set rescue mode automaticly and generate SSH Key if not present
- `hetzner_pve_hetzner_api_user` [default: `secret` ]: Hetzner API user
- `hetzner_pve_hetzner_api_pass` [default: `secret` ]: Hetzner API password
- `hetzner_pve_luks_pass` [default: `secret` ]: Luks encryption password
- `hetzner_pve_ssh_keys` [default: `secret` ]: Your SSH Pubkey to login (openssh,busybox boot) - If no SSH Key is provided, ansible will create a new one at `~/.ssh/id_ed25519_ansible`
- `hetzner_pve_acme_mail` [default: `email@example.com` ]: Mail address for acme by letsencrypt
- `hetzner_pve_acme_domain` [default: `vmhost.domain.com` ]: fqdn from your vmhost - must reachable from external
- `hetzner_pve_storagebox_server`: storagebox / cifs account to automount
- `hetzner_pve_custom_packages`: list of custom packages to install
- `hetzner_pve_setup_opnsense` [default: `true`]: Provision a OPNsense vm Firewall
- `hetzner_pve_setup_opnsense_force` [default: `true`]: Destroy the old vm and recreate
- `hetzner_pve_setup_opnsense_enable_ipv6` [default: `false`]: Enable IPV6
- `hetzner_pve_setup_opnsense_settings_lan_dhcpd` [default: `true`]: Start DHCP on LAN Bridge
- `hetzner_pve_setup_opnsense_user` [default: `ansible`]: Create a ansible user for ansible
- `hetzner_pve_network_lan_subnet` [default: 24"]: Internal LAN Subnet
- `hetzner_pve_network_lan_ip` [default: "192.168.49.2"]: Internal LAN IP for Proxmox
- `hetzner_pve_network_vm_lan_ip` [default: "192.168.49.254"]: Internal LAN IP for OPNsense
- `hetzner_pve_network_vm_lan_dhcp_from` [default: "192.168.49.100"]: OPNsense DHCP range start
- `hetzner_pve_network_vm_lan_dhcp_to` [default: "192.168.49.150"]: OPNsense DHCP range end

#### Howto

- ansible-playbook playbook.yml -i inventory/hosts
- When playbook finished

      Please change OPNsense password!!!
      Gui is only reachable by {{ ipify_public_ip  }}

      OPNsense GUI: https://{{ ansible_host }}
          Username: root
          Password: opnsense

      Proxmox GUI: https://{{ ansible_host }}:{{ hetzner_pve_setup_opnsense_fwd_proxmox_gui_port }}
          Username: root
          Password: <yoursecret>

- Inside `tool` folder, there are some utils to help with development/debugging.

      Please edit tool/.env file accordingly and run:

      cd tool
      . run                    # Run playbook.yml with default settings
      . run _TST_              # Run tool/test.yml with default settings; this can be useful to execute specific tasks from the playbook.yml, in isolation
      . run _RSC_ --nh 0 && . run -vvv   # Run tool/rescue.yml in same thread and after run main playbook with verbosity level 1 and NOHUP activated
      . run --help  # shows the help page of this tool

#### Todos

- Testing and improvements

thanks to https://github.com/extremeshok/xshok-proxmox
