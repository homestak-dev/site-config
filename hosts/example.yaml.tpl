# hosts/example.yaml.tpl - Physical machine configuration template
#
# Copy this file and customize for your physical Proxmox host.
# This is consumed by Ansible for host configuration.
#
# Naming: Use the hostname of the physical machine (e.g., pve1.yaml)

# Machine identifier (should match filename without .yaml)
host: mypve

# Access configuration
access:
  # SSH username for remote access
  ssh_user: root
  # References to keys in secrets.yaml.ssh_keys
  authorized_keys:
    - admin           # -> secrets.ssh_keys.admin
