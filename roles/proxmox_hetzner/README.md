# Proxmox Hetzner Role

Ansible role for automated Proxmox VE installation and configuration on Hetzner servers with automatic disk detection and ZFS setup.

## Features

- **Automatic disk detection**: Automatically detects available disks and configures storage
- **ZFS support**: Creates ZFS pools with automatic RAID configuration
- **Network configuration**: Sets up VM bridges and network interfaces
- **Security**: Uses ansible-vault for sensitive data
- **Monitoring**: Includes health checks and monitoring scripts
- **Hetzner integration**: Optimized for Hetzner server infrastructure

## Requirements

- Ansible 2.9+
- Debian Bookworm or Bullseye
- Root access to target servers
- Hetzner server with multiple disks (recommended)

## Role Variables

### Required Variables

These variables should be defined in your vault file (`inventory/group_vars/pve/20_vault.yml`):

```yaml
# Hetzner API credentials
hetzner_api_user: "your_hetzner_username"
hetzner_api_password: "your_hetzner_password"

# Proxmox root password
proxmox_root_password: "your_secure_root_password"

# Proxmox user passwords
proxmox_user_passwords:
  admin: "your_admin_password"
  api_user: "your_api_user_password"

# SSH keys for Proxmox users
proxmox_ssh_keys:
  - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your_key_here"

# LUKS encryption password
luks_password: "your_luks_encryption_password"
```

### Optional Variables

```yaml
# Proxmox configuration
proxmox_version: "8"
proxmox_repository: "deb [arch=amd64] http://mirror.hetzner.com/debian/pve {{ ansible_facts.distribution_release }} pve-no-subscription"

# Network configuration
proxmox_network:
  vm_bridge_name: "vmbr50"
  vm_network_lan_subnet: "24"
  vm_network_lan_ip: "10.0.0.1"
  vm_network_vm_lan_ip: "10.0.0.254"
  vm_network_vm_lan_dhcp_from: "10.0.0.50"
  vm_network_vm_lan_dhcp_to: "10.0.0.150"
  enable_dhcp: false

# Storage configuration
proxmox_storage:
  enable_zfs: true
  zfs_pool_name: "rpool"
  zfs_datasets:
    - name: "isos"
      mountpath: "/isos"
    - name: "backups"
      mountpath: "/backups"
    - name: "vm-drives"
      mountpath: "/vm-drives"

# Disk detection settings
disk_detection:
  min_disk_size_gb: 10
  exclude_patterns:
    - "loop*"
    - "ram*"
    - "sr*"
    - "fd*"
```

## Dependencies

- `community.general` collection (for ZFS and Proxmox modules)
- `ansible.posix` collection (for systemd and other modules)

## Example Playbook

```yaml
---
- name: "Install Proxmox on Hetzner servers"
  hosts: pve
  user: root
  gather_facts: true
  vars_files:
    - inventory/group_vars/pve/01 vars.yml
    - inventory/group_vars/pve/20_vault.yml

  tasks:
    - name: "Install and configure Proxmox"
      ansible.builtin.include_role:
        name: proxmox_hetzner
```

## Tags

The role supports the following tags for selective execution:

- `disk_detection`: Run only disk detection tasks
- `system_preparation`: Run only system preparation tasks
- `proxmox_installation`: Run only Proxmox installation tasks
- `storage_setup`: Run only storage setup tasks
- `network_configuration`: Run only network configuration tasks
- `proxmox_configuration`: Run only Proxmox configuration tasks
- `post_installation`: Run only post-installation tasks

## Disk Detection

The role automatically detects available disks and configures storage based on:

1. **Disk size**: Filters disks by minimum size (default: 10GB)
2. **Disk type**: Includes only physical disks (excludes loop, ram, etc.)
3. **RAID configuration**: Automatically configures RAID based on available disks
4. **ZFS setup**: Creates ZFS pools with appropriate RAID levels

## Security Features

- Uses ansible-vault for sensitive data
- Configures SSH with secure settings
- Sets up firewall rules
- Enables LUKS encryption (optional)
- Configures proper file permissions

## Monitoring

The role includes:

- Health check script (`/usr/local/bin/proxmox-health-check.sh`)
- System information script (`/usr/local/bin/proxmox-system-info.sh`)
- Log monitoring configuration
- Automatic health checks via cron

## Testing

Use the provided test playbook:

```bash
ansible-playbook -i inventory/servers playbooks/test_proxmox_hetzner.yml --ask-vault-pass
```

## License

MIT

## Author Information

Created by Atlasix Tech for automated Proxmox deployment on Hetzner infrastructure.
