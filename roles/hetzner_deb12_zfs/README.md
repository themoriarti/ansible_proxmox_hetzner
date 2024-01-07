# hetzner_deb12_zfsroot

Barebones installation of Debian 12 bookmark on a Hetzner server using ZFS for the boot

Force specfied host to Hetzner rescue mode
Compile latest OpenZFS
Set up Debian 12

## Original sources:

[Hetzner scripr to install ZFS on rescue](https://gist.github.com/tijszwinkels/966ec9b38b190bf80c2b2e4cfddf252a)

[Install Debian on ZFS on Hetzer](https://github.com/terem42/zfs-hetzner-vm)

[OpenZFS on Debian 12](https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bookworm%20Root%20on%20ZFS.html#id8)

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

- `hetzner_api_user`: [default: `secret`]: api user id for the Hetzner robot API, overwritten with vaulted value in ./vars/main.yml
- `hetzner_api_pass`: [default: `secret`]: api user id for the Hetzner robot API, overwritten with vaulted value in ./vars/main.yml
- `hetzner_api_ssh_keys`: [optional]: I don't know what format to set these keys in to push to the Hetzner robot API

- `fail2ban_loglevel`: [default: `3`, or `INFO` in newer versions]: Sets the loglevel output (e.g. `1 = ERROR`, `2 = WARN`, `3 = INFO`, `4 = DEBUG`)
- `fail2ban_logtarget`: [default: `/var/log/fail2ban.log`]: Sets the log target. This could be a file, SYSLOG, STDERR or STDOUT
- `fail2ban_syslog_target`: [default: `/var/log/fail2ban.log`]:
- `fail2ban_syslog_facility`: [default: `1`]:
- `fail2ban_socket`: [default: `/var/run/fail2ban/fail2ban.sock`]: Sets the socket file, which is used to communicate with the daemon
- `fail2ban_pidfile`: [default: `/var/run/fail2ban/fail2ban.pid`]: Sets the pid file, which is used to to store the process ID of the daemon (Only works on `fail2ban >= 0.8.9`)
- `fail2ban_dbpurgeage`: [default: `86400`]: Sets age at which bans should be purged from the database

- `fail2ban_ignoreips`: [default: `[127.0.0.1/8]`]: Which IP address/CIDR mask/DNS host should be ignored from fail2ban's actions
- `fail2ban_bantime`: [default: `600`]: Sets the bantime
- `fail2ban_maxretry`: [default: `3`]: Maximum number of retries before the host is put into jail
- `fail2ban_findtime`: [default: `600`]: A host is banned if it has generated `fail2ban_maxretry` during the last `fail2ban_findtime`
- `fail2ban_backend`: [default: `auto`]: Specifies the backend used to get files modification. For Debian 12, `systemd` is required
- `fail2ban_banaction`: [default: `iptables-multiport`]: Sets the global/default banaction
- `fail2ban_banaction_allports`: [default: `iptables-allports`]: Sets the global/default banaction for allports
- `fail2ban_mta`: [default: `sendmail`]: Email action
- `fail2ban_protocol`: [default: `tcp`]: Sets the default protocol
- `fail2ban_chain`: [default: `INPUT`]: Specifies the chain where jumps would need to be added in iptables-\* actions
- `fail2ban_action`: [default: `%(action_)s`]: Default action. **Note that variables (including the actions defined elsewhere in the config files) must be wrapped in python-style `%(` and `)s` so they are expanded**
- `fail2ban_sendername`: [default: `Fail2ban`]: The 'from' name for emails sent by mta actions. NB: Use `fail2ban_sender` to set the 'from' email address.
- `fail2ban_sender`: [optional]: The 'from' address for emails sent by mta actions.
- `fail2ban_filterd_path`: [optional]: Path to directory containing filters to copy (**note the trailing slash**)
- `fail2ban_actiond_path`: [optional]: Path to directory containing actions to copy (**note the trailing slash**)
- `fail2ban_jaild_path`: [optional]: Path to directory containing jails to copy (**note the trailing slash**)

- `fail2ban_services` [default see `defaults/main.yml`]: Service definitions
- `fail2ban_services.{n}.name` [required]: Service name (e.g. `ssh`)
- `fail2ban_services.{n}.enabled` [default: `true`]: Whether or not enabled
- `fail2ban_services.{n}.*` [optional]: Name of the option
- `fail2ban_services.{n}.*.*` [optional]: Value of the option

### For version >= 0.11.1

- `fail2ban_bantime_increment`: [default: `true`]: Increases bantime after being banned before
- `fail2ban_bantime_factor`: [default: `1`]: Bantime increase factor for `bantime_formula` or `bantime_multipliers`
- `fail2ban_bantime_formula`: [default: `'ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * banFactor'`]: Formula that will be used to calculate the increased bantime. **Note that you can either use `bantime_formula` or `bantime_multipliers` while `bantime_multipliers` takes precedence.**
- `fail2ban_bantime_overalljails`: [default: `false`]: Ban IPs for all jails if multiple are defined
- `fail2ban_bantime_rndtime`: [optional]: Option for smart bots that try to access after the bantime immediately
- `fail2ban_bantime_multipliers`: [optional]: Multiplier to use instead of bantime_formula. For example `1 2 4 8 16 32 64`. **Note for bantime = 600 and bantime_factor=1 this would be `600*1*1, 600*1*2...`**

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

## License

MIT

## Author Information

Mischa ter Smitten (based on work of [ANXS](https://github.com/ANXS))

## Feedback, bug-reports, requests, ...

Are [welcome](https://github.com/Oefenweb/ansible-fail2ban/issues)!
