# hetzner_deb12_zfsroot

Barebones installation of Debian 12 bookmark on a Hetzner server using ZFS for the boot

** TOTALLY WIPES THE SERVER **

Force specfied host to Hetzner rescue mode
Compile latest OpenZFS
Sets up Debian 12 with minimal install

## Role Variables

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

## Dependencies

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

## Example Playbook

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

## License

BSD

## Author Information

An optional section for the role authors to include contact information, or a website (HTML is not allowed).

## Requirements

None

## Variables

this is all from the template to be updated as role written

## Dependencies

None

## Example(s)

### Simple

```yaml
---
- hosts: all
  roles:
    - oefenweb.fail2ban
```

### Enable sshd filter (with non-default settings)

```yaml
---
- hosts: all
  roles:
    - oefenweb.fail2ban
  vars:
    fail2ban_services:
      # In older versions of Fail2Ban this is called ssh
      - name: sshd
        port: 2222
        maxretry: 5
        bantime: -1
```

### Add custom filters (from outside the role)

```yaml
---
- hosts: all
  roles:
    - oefenweb.fail2ban
  vars:
    fail2ban_filterd_path: ../../../files/fail2ban/etc/fail2ban/filter.d/
    fail2ban_services:
      - name: apache-wordpress-logins
        port: http,https
        filter: apache-wordpress-logins
        logpath: /var/log/apache2/access.log
        maxretry: 5
        findtime: 120
```

## References:

[Hetzner scripr to install ZFS on rescue](https://gist.github.com/tijszwinkels/966ec9b38b190bf80c2b2e4cfddf252a)

[Install Debian on ZFS on Hetzer](https://github.com/terem42/zfs-hetzner-vm)

[OpenZFS on Debian 12](https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bookworm%20Root%20on%20ZFS.html#id8)

## License

MIT

## Author Information

Mischa ter Smitten (based on work of [ANXS](https://github.com/ANXS))

## Feedback, bug-reports, requests, ...

Are [welcome](https://github.com/Oefenweb/ansible-fail2ban/issues)!
