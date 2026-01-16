# site-config

This file provides guidance to Claude Code when working with this repository.

## Overview

Site-specific configuration for homestak deployments using a normalized 5-entity YAML structure. Separates concerns: physical machines, PVE instances, VM templates, security postures, and deployment topologies.

## Entity Model (5NF)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   hosts/    │     │  postures/  │     │    vms/     │
│ (physical)  │     │ (security)  │     │ (templates) │
│  Ansible    │     │   Ansible   │     │ Tofu/Packer │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ FK: host          │ FK: posture       │ FK: vm
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐
│   nodes/    │◄────│   envs/     │
│  (PVE API)  │     │ (templates) │
│    Tofu     │     │    Tofu     │
└─────────────┘     └─────────────┘
```

**Note:** Primary keys are derived from filenames (e.g., `hosts/father.yaml` → identifier is `father`).
Envs are node-agnostic templates; the target host is specified at deploy time via `run.sh --host`.
Foreign keys (FK) are explicit references between entities.

## Structure

```
site-config/
├── site.yaml              # Non-sensitive site-wide defaults
├── secrets.yaml           # ALL sensitive values (SOPS encrypted)
├── secrets.yaml.enc       # Encrypted version (committed to private forks)
├── hosts/                 # Physical machines
│   └── {name}.yaml        # SSH access (Phase 4: network, storage)
├── nodes/                 # PVE instances (filename must match PVE node name)
│   ├── {nodename}.yaml    # e.g., father.yaml for node named "father"
│   └── nested-pve.yaml    # Nested PVE (parent_node reference)
├── postures/              # Security postures for environments
│   ├── dev.yaml           # Permissive: SSH password auth, sudo nopasswd
│   ├── prod.yaml          # Hardened: no root login, fail2ban enabled
│   └── local.yaml         # On-box execution posture
├── vms/                   # VM templates
│   ├── presets/           # Size presets (small, medium, large)
│   │   └── {size}.yaml
│   └── {name}.yaml        # Custom templates
└── envs/                  # Deployment topology templates (node-agnostic)
    ├── dev.yaml           # env-specific config, node at deploy time
    ├── test.yaml
    ├── k8s.yaml
    ├── ansible-test.yaml  # Ansible role validation
    └── nested-pve.yaml    # Integration testing
```

## Entity Definitions

### site.yaml
Non-sensitive defaults inherited by all entities:
- `defaults.timezone` - System timezone (e.g., America/Denver)
- `defaults.domain` - Network domain
- `defaults.ssh_user` - Default SSH user (typically root)
- `defaults.bridge` - Default network bridge
- `defaults.gateway` - Default gateway for static IPs
- `defaults.packages` - Base packages installed on all VMs
- `defaults.pve_remove_subscription_nag` - Remove PVE subscription popup (bool)
- `defaults.packer_release` - Packer release for image downloads (default: `latest`)

**Note:** `datastore` was moved to nodes/ in v0.13 - it's now required per-node.

**Packer images:** The `latest` release is the primary source for packer images. Most versioned releases don't include images; automation defaults to `packer_release: latest`. Override with a specific version (e.g., `v0.20`) only when needed.

### secrets.yaml
ALL sensitive values in one file (encrypted):
- `api_tokens.{node}` - Proxmox API tokens
- `passwords.vm_root` - VM root password hash
- `ssh_keys.{user@host}` - SSH public keys (identifier matches key comment)

### hosts/{name}.yaml
Physical machine configuration for SSH access and host management.
Primary key derived from filename (e.g., `father.yaml` → `father`).

**Core fields:**
- `host` - Hostname (matches filename)
- `domain` - Network domain (extracted from FQDN or resolv.conf)

**Network section:**
- `network.interfaces.{bridge}` - Bridge configurations:
  - `type` - Interface type (bridge)
  - `ports` - Physical ports attached to bridge
  - `address` - IP address with CIDR (e.g., 10.0.12.61/24)
  - `gateway` - Default gateway (if default route uses this bridge)

**Storage section:**
- `storage.zfs_pools[]` - ZFS pool configurations:
  - `name` - Pool name
  - `devices` - Backing devices

**Hardware section:**
- `hardware.cpu_cores` - Number of CPU cores
- `hardware.memory_gb` - Total RAM in GB

**Access section:**
- `access.ssh_user` - SSH username (default: root)
- `access.ssh_port` - SSH port (default: 22)
- `access.authorized_keys` - References to secrets.ssh_keys by user@host identifier (FK)

**SSH section:**
- `ssh.permit_root_login` - Root login policy (yes/no/prohibit-password)
- `ssh.password_authentication` - Password auth policy (yes/no)

**Git tracking:** Site-specific host configs are excluded from git via `.gitignore`. Generate your host config with `make host-config` on each physical host.

### nodes/{name}.yaml
PVE instance configuration for API access.
**Important:** Filename must match the actual PVE node name (check with `pvesh get /nodes`).
Primary key derived from filename (e.g., `father.yaml` → `father`).
- `host` - FK to hosts/ (physical machine)
- `parent_node` - FK to nodes/ (for nested PVE, instead of host)
- `api_endpoint` - Proxmox API URL
- `api_token` - Reference to secrets.api_tokens (FK)
- `datastore` - Storage for VMs (REQUIRED in v0.13+)
- `ip` - Node IP for SSH access

**Git tracking:** Site-specific node configs (e.g., `father.yaml`, `mother.yaml`) are excluded from git via `.gitignore`. Only `nested-pve.yaml` is tracked (required for integration testing). Generate your node config with `make node-config` on each PVE host.

**Migration (v0.13):** If upgrading from earlier versions, regenerate node configs:
```bash
make node-config FORCE=1
```

### postures/{name}.yaml
Security posture configuration for environments.
Primary key derived from filename (e.g., `dev.yaml` → `dev`).
Referenced by envs via `posture:` FK.

- `ssh_port` - SSH port (default: 22)
- `ssh_permit_root_login` - Root login policy (yes/no/prohibit-password)
- `ssh_password_authentication` - Password auth policy (yes/no)
- `sudo_nopasswd` - Passwordless sudo (bool)
- `fail2ban_enabled` - Enable fail2ban (bool)
- `packages` - Additional packages (merged with site.yaml packages)

Available postures:
- `dev` - Permissive (SSH password auth, sudo nopasswd)
- `prod` - Hardened (no root login, fail2ban enabled)
- `local` - On-box execution posture

### vms/presets/{size}.yaml
Size presets for VM resource allocation.
Primary key derived from filename (e.g., `small.yaml` → `small`).
- `cores` - Number of CPU cores
- `memory` - RAM in MB
- `disk` - Disk size in GB

Available presets: `xsmall` (1c/1GB/8GB), `small` (2c/2GB/8GB), `medium` (2c/4GB/16GB), `large` (4c/8GB/32GB), `xlarge` (8c/16GB/64GB)

### vms/{name}.yaml
VM template defining base configuration.
Primary key derived from filename (e.g., `nested-pve.yaml` → `nested-pve`).
- `image` - Base image name (FK to packer image)
- `preset` - FK to vms/presets/ (optional, for resource inheritance)
- `cores` - CPU cores (overrides preset)
- `memory` - RAM in MB (overrides preset)
- `disk` - Disk size in GB (overrides preset)
- `bridge` - Network bridge (optional, defaults from site.yaml)
- `ip` - IP address or "dhcp" (optional)
- `gateway` - Gateway IP for static IPs (optional, defaults from site.yaml)
- `packages` - Cloud-init packages (optional)

**Merge order:** preset → template → instance overrides

### envs/{name}.yaml
Deployment topology template defining VM layouts.
Primary key derived from filename (e.g., `dev.yaml` → `dev`).
Node-agnostic: target host specified at deploy time via `run.sh --host`.
- `posture` - FK to postures/ (default: dev)
- `vmid_base` - Base VM ID for auto-allocation (omit for PVE auto-assign)
- `vms[]` - List of VM instances:
  - `name` - VM hostname
  - `template` - FK to vms/ template
  - `vmid` - Explicit VM ID (overrides vmid_base + index)
  - (any template field can be overridden per-instance)

## Discovery Mechanism

Other homestak tools find site-config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../site-config/` sibling directory
3. `/opt/homestak/site-config/` fallback

## Dependency Installation

```bash
sudo make install-deps  # Install age and sops
```

Installs:
- `age` via apt
- `sops` v3.11.0 via .deb from GitHub releases

## Config Generation

Run on a PVE host to bootstrap configuration:

```bash
make host-config   # Generate hosts/{hostname}.yaml from system info
make node-config   # Generate nodes/{hostname}.yaml from PVE info

# Force overwrite existing files
make host-config FORCE=1
make node-config FORCE=1
```

`host-config` gathers: domain, network bridges, ZFS pools, hardware (CPU/RAM), SSH settings
`node-config` gathers: PVE API endpoint, datastore, IP address (requires PVE installed)

## Secrets Management

Only `secrets.yaml` is encrypted - all other files are non-sensitive.

```bash
make setup    # Configure git hooks, check dependencies
make encrypt  # Encrypt secrets.yaml -> secrets.yaml.enc
make decrypt  # Decrypt secrets.yaml.enc -> secrets.yaml
make check    # Show setup status
make validate # Validate YAML syntax
```

### Git Hooks
- **pre-commit**: Auto-encrypts secrets.yaml, blocks plaintext commits
- **post-checkout**: Auto-decrypts secrets.yaml.enc
- **post-merge**: Delegates to post-checkout

## Reference Resolution

Config files use references (FK) to secrets.yaml:
```yaml
# nodes/father.yaml
api_token: father  # Resolves to secrets.api_tokens.father
```

iac-driver's ConfigResolver resolves all references at runtime and generates flat tfvars for tofu.

## Related Repos

| Repo | Uses |
|------|------|
| iac-driver | All entities - resolves config for tofu (tfvars.json) and ansible (ansible-vars.json) |
| tofu | Receives flat tfvars from iac-driver (no direct site-config access) |
| ansible | Receives resolved vars from iac-driver; uses `hosts/*.yaml` for host configuration |
| bootstrap | Clones and sets up site-config |

## Migration from tfvars

Old structure (v0.3.x):
- `hosts/*.tfvars` → `hosts/*.yaml` + `nodes/*.yaml` + `secrets.yaml`
- `envs/*/terraform.tfvars` → `envs/*.yaml` (flattened)

## License

Apache 2.0
