# config

This file provides guidance to Claude Code when working with this repository.

## Overview

Site-specific configuration for homestak deployments. Separates concerns: physical machines, PVE instances, security postures, size presets, node specifications, and deployment manifests.

## Entity Model

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   hosts/    │     │  postures/  │     │   specs/    │
│ (physical)  │     │ (security)  │     │ (what to    │
│  Ansible    │     │   Ansible   │     │   become)   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ FK: host          │ FK: posture       │ FK: spec
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   nodes/    │◄────│ manifests/  │────▶│  presets/   │
│  (PVE API)  │     │ (topology)  │     │ (VM sizes)  │
│    Tofu     │     │  Operator   │     │    Tofu     │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Note:** Primary keys are derived from filenames (e.g., `hosts/srv1.yaml` → identifier is `srv1`).
Foreign keys (FK) are explicit references between entities.

## Structure

```
config/
├── site.yaml.example      # Template for site-wide defaults (tracked)
├── site.yaml              # Local site-wide defaults (gitignored, created from .example)
├── secrets.yaml.example   # Template for secrets (tracked)
├── secrets.yaml           # Local secrets (gitignored, created from .example or decrypted from .enc)
├── defs/                  # JSON Schema definitions
│   ├── spec.schema.json
│   ├── posture.schema.json
│   └── manifest.schema.json
├── hosts/                 # Physical machines
│   └── {name}.yaml        # SSH access (Phase 4: network, storage)
├── nodes/                 # PVE instances (filename must match PVE node name)
│   └── {nodename}.yaml    # e.g., srv1.yaml for node named "srv1"
├── postures/              # Security postures with auth model
│   ├── dev.yaml           # network trust, permissive SSH
│   ├── stage.yaml         # site_token auth, hardened SSH
│   ├── prod.yaml          # node_token auth, hardened SSH
│   └── local.yaml         # network trust (on-box)
├── specs/                 # Node specifications (what to become)
│   ├── base.yaml          # General-purpose VM (user, packages, timezone)
│   └── pve.yaml           # PVE hypervisor (proxmox packages, services)
├── presets/               # Size presets (vm- prefix)
│   ├── vm-xsmall.yaml
│   ├── vm-small.yaml
│   ├── vm-medium.yaml
│   ├── vm-large.yaml
│   └── vm-xlarge.yaml
└── manifests/             # Manifest definitions (v0.39+)
    ├── n1-push.yaml       # Flat single-node test (push mode)
    ├── n1-pull.yaml       # Flat single-node test (pull mode)
    ├── n2-tiered.yaml     # 2-level tiered PVE test
    ├── n2-mixed.yaml      # Push-mode PVE + pull-mode VM (ST-5)
    └── n3-deep.yaml       # 3-level tiered PVE test
```

## Template Pattern (.example files)

The repo ships `.example` template files; actual config files are gitignored and created locally:

| Template | Local File | Created By |
|----------|-----------|------------|
| `site.yaml.example` | `site.yaml` | `make init-site` |
| `secrets.yaml.example` | `secrets.yaml` | `make init-secrets` |

- `make init-site` copies `site.yaml.example` to `site.yaml` if it doesn't exist
- `make init-secrets` decrypts `secrets.yaml.enc` if an age key is available, otherwise copies `secrets.yaml.example`
- This allows new users to get started without an age key (they get a working template to edit)

## Lifecycle Configuration

Configuration for the create → config → run → destroy lifecycle model. Previously in `v2/`, now consolidated at the top level.

**Lifecycle coverage:**
- **create**: `presets/` + manifest `nodes[]` (infrastructure provisioning)
- **config**: `specs/` + `postures/` (fetch spec, apply configuration)

### Unified Node Model

All compute entities (VMs, containers, PVE hosts, k3s nodes) are "nodes" with a common lifecycle:

```
node (abstract)
├── type: pve     → Proxmox VE hypervisor
├── type: vm      → KVM virtual machine
├── type: ct      → LXC container
└── type: k3s     → Kubernetes node (future)
```

Node properties (type, spec, preset, image, disk) are defined inline in manifest `nodes[]` entries.

### specs/{name}.yaml

Specifications define "what a node should become" - packages, services, users, configuration. Consumed by `homestak spec get` (config phase) and `./run.sh config` (config phase).

Schema: `defs/spec.schema.json`

| Section | Required | Description |
|---------|----------|-------------|
| `schema_version` | Yes | Must be `1` |
| `identity` | No | Hostname/domain, defaults from hostname and site.yaml |
| `network` | No | Static IP config, omit for DHCP |
| `access` | No | Posture + users, defaults to `dev` posture |
| `platform` | No | Packages + services |
| `config` | No | Type-specific configuration |
| `run` | No | Run phase convergence settings |

**FK resolution (runtime):**
- `access.posture` → `postures/{value}.yaml`
- `access.users[].ssh_keys[]` → `secrets.yaml → ssh_keys.{value}`

**SSH key default:** When `ssh_keys` is omitted from a spec's user entry, all keys from `secrets.ssh_keys` are injected automatically. Explicit `ssh_keys[]` entries restrict injection to only the listed keys.

**Available specs:**

| Spec | Purpose |
|------|---------|
| `base` | General-purpose VM: user with sudo, ssh keys, packages, timezone |
| `pve` | PVE hypervisor: proxmox packages, services, PVE config |

### Auth Model (Config Phase, #231)

Authentication for the config phase uses HMAC-SHA256 provisioning tokens. ConfigResolver mints a token per-VM carrying the node identity and spec FK. The server verifies the signature against `secrets.auth.signing_key`.

**Token flow:** ConfigResolver → `auth_token` in tfvars → cloud-init `HOMESTAK_TOKEN` → server `verify_provisioning_token()`

**Note:** Posture files still contain `auth.method` (network/site_token/node_token) which is used for SSH/sudo/security settings but no longer drives spec authentication.

**Posture schema:**

Schema: `defs/posture.schema.json`

```yaml
# postures/stage.yaml
auth:
  method: site_token

ssh:
  port: 22
  permit_root_login: "prohibit-password"
  password_authentication: "no"

sudo:
  nopasswd: false

fail2ban:
  enabled: true

packages:
  - net-tools
```

## Entity Definitions

### site.yaml
Non-sensitive defaults inherited by all entities:
- `defaults.timezone` - System timezone (e.g., America/Denver)
- `defaults.domain` - Network domain (optional, blank by default)
- `defaults.ssh_user` - Default SSH user (typically root)
- `defaults.bridge` - Default network bridge
- `defaults.gateway` - Default gateway for static IPs
- `defaults.packages` - Base packages installed on all VMs
- `defaults.pve_remove_subscription_nag` - Remove PVE subscription popup (bool)
- `defaults.packer_release` - Packer release for image downloads (default: `latest`)
- `defaults.spec_server` - Spec server URL for create → config flow (default: empty/disabled)
- `defaults.dns_servers` - DNS servers for VMs and PVE bridge config (list of IPs, default: empty)

**Note:** `datastore` was moved to nodes/ in v0.13 - it's now required per-node.

**Packer images:** The `latest` release is the primary source for packer images. Most versioned releases don't include images; automation defaults to `packer_release: latest`. Override with a specific version (e.g., `v0.20`) only when needed.

### secrets.yaml
ALL sensitive values in one file (encrypted):
- `api_tokens.{node}` - Proxmox API tokens
- `passwords.vm_root` - VM root password hash
- `ssh_keys.{user@host}` - SSH public keys (identifier matches key comment)
- `auth.signing_key` - HMAC-SHA256 signing key for provisioning tokens (#231)

**Signing key:**
```yaml
# secrets.yaml structure for provisioning token authentication
auth:
  signing_key: "<hex-encoded 256-bit key>"  # Generate: python3 -c "import secrets; print(secrets.token_hex(32))"
```

### hosts/{name}.yaml
Physical machine configuration for SSH access and host management.
Primary key derived from filename (e.g., `srv1.yaml` → `srv1`).

**Core fields:**
- `host` - Hostname (matches filename)
- `domain` - Network domain (extracted from FQDN or resolv.conf)

**Network section:**
- `network.interfaces.{bridge}` - Bridge configurations:
  - `type` - Interface type (bridge)
  - `ports` - Physical ports attached to bridge
  - `address` - IP address with CIDR (e.g., 198.51.100.61/24)
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

**iac-driver usage (v0.36+):** When `--host X` is specified and `nodes/X.yaml` doesn't exist, iac-driver falls back to `hosts/X.yaml` for SSH-only access. This enables provisioning fresh Debian hosts before PVE is installed:
```bash
# Create host config on fresh Debian machine
ssh root@<ip> "cd ~homestak/config && make host-config"

# Provision PVE using hosts/ config (no nodes/ yet)
./run.sh --scenario pve-setup --host daughter

# After pve-setup, nodes/daughter.yaml is auto-generated
```

### nodes/{name}.yaml
PVE instance configuration for API access.
**Important:** Filename must match the actual PVE node name (check with `pvesh get /nodes`).
Primary key derived from filename (e.g., `srv1.yaml` → `srv1`).
- `host` - FK to hosts/ (physical machine)
- `parent_node` - FK to nodes/ (for nested PVE, instead of host)
- `api_endpoint` - Proxmox API URL
- `api_token` - Reference to secrets.api_tokens (FK)
- `datastore` - Storage for VMs (REQUIRED in v0.13+)
- `ip` - Node IP for SSH access

**Git tracking:** All node configs are excluded from git via `.gitignore`. The operator generates node configs dynamically via `make node-config` on each PVE host.

**Migration (v0.13):** If upgrading from earlier versions, regenerate node configs:
```bash
make node-config FORCE=1
```

### postures/{name}.yaml
Security posture configuration with nested structure and auth model.
Primary key derived from filename (e.g., `dev.yaml` → `dev`).
Referenced by specs via `access.posture:` FK.

Schema: `defs/posture.schema.json`

- `auth.method` - Auth method (vestigial for spec auth, used for posture labeling)
- `ssh.port` - SSH port (default: 22)
- `ssh.permit_root_login` - Root login policy (yes/no/prohibit-password)
- `ssh.password_authentication` - Password auth policy (yes/no)
- `sudo.nopasswd` - Passwordless sudo (bool)
- `fail2ban.enabled` - Enable fail2ban (bool)
- `packages` - Additional packages (merged with site.yaml packages)

Available postures:
- `dev` - Permissive (SSH password auth, sudo nopasswd)
- `stage` - Intermediate (hardened SSH, sudo requires password)
- `prod` - Hardened (no root login, fail2ban enabled)
- `local` - On-box execution (same as dev)

### presets/{name}.yaml
Size presets for VM resource allocation. Uses `vm-` prefix to allow future preset types.
Primary key derived from filename (e.g., `vm-small.yaml` → `vm-small`).
- `cores` - Number of CPU cores
- `memory` - RAM in MB
- `disk` - Disk size in GB

Available presets: `vm-xsmall` (1c/1GB/8GB), `vm-small` (2c/2GB/10GB), `vm-medium` (2c/4GB/20GB), `vm-large` (4c/8GB/40GB), `vm-xlarge` (8c/16GB/80GB)

### manifests/{name}.yaml
Manifest definitions for infrastructure orchestration.
Primary key derived from filename (e.g., `n2-tiered.yaml` → `n2-tiered`).

Schema v2 fields:
- `schema_version` - Must be 2 for graph-based nodes format
- `name` - Manifest identifier
- `description` - Human-readable description
- `pattern` - Topology shape: `flat` or `tiered`
- `nodes[]` - List of graph nodes:
  - `name` - Node identifier (VM hostname)
  - `type` - Node type: `vm`, `ct`, `pve`
  - `spec` - FK to specs/
  - `preset` - FK to presets/ (vm- prefixed)
  - `image` - Cloud image name
  - `vmid` - Explicit VM ID
  - `disk` - Disk size override
  - `parent` - FK to another node name (null/omitted = root)
  - `execution.mode` - Per-node execution mode (push/pull)
- `settings` - Optional settings (same as v1, plus `on_error`)
  - `on_error` - Error handling: `stop`, `rollback`, `continue` (default: stop)

Built-in manifests: `n1-push` (flat, push mode), `n1-pull` (flat, pull mode), `n2-tiered` (tiered 2-level), `n2-mixed` (tiered, push-mode PVE + pull-mode VM), `n3-deep` (tiered 3-level)

## Discovery Mechanism

Other homestak tools find config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../config/` sibling directory (dev workspace)
3. `~homestak/config/` (bootstrap install)

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

# Direct script usage (supports --help, --force)
./scripts/host-config.sh --help
./scripts/node-config.sh --force
```

`host-config` gathers: domain, network bridges, ZFS pools, hardware (CPU/RAM), SSH settings
`node-config` gathers: PVE API endpoint, datastore, IP address (requires PVE installed)

**Note:** `host-config.sh` emits `interfaces: {}` (empty map) when no bridges exist, avoiding a bare `interfaces:` (YAML null) that would cause downstream parsing issues.

## Secrets Management

Only `secrets.yaml` is encrypted - all other files are non-sensitive.

```bash
make setup        # Configure git hooks, check dependencies (age/sops optional)
make init-site    # Create site.yaml from site.yaml.example (if missing)
make init-secrets # Decrypt secrets.yaml.enc or copy secrets.yaml.example (if missing)
make encrypt      # Encrypt secrets.yaml -> secrets.yaml.enc
make decrypt      # Decrypt secrets.yaml.enc -> secrets.yaml (sets 600 permissions)
make check        # Show setup status
make validate     # Validate YAML syntax + schemas
```

**Note:** `make setup` no longer requires age/sops to be installed. New users can run setup, then `make init-site` and `make init-secrets` to get working config files from the `.example` templates without encryption tooling.

### Schema Validation

The `scripts/validate-schemas.sh` script validates YAML files against JSON schemas:

```bash
# Validate all specs, postures, and manifests
./scripts/validate-schemas.sh

# Validate specific files
./scripts/validate-schemas.sh specs/pve.yaml postures/dev.yaml

# JSON output for CI/scripting
./scripts/validate-schemas.sh --json
```

**Schema mapping:**
| Directory | Schema |
|-----------|--------|
| `specs/*.yaml` | `defs/spec.schema.json` |
| `postures/*.yaml` | `defs/posture.schema.json` |
| `manifests/*.yaml` (v2) | `defs/manifest.schema.json` |

**Exit codes:**
- `0` - All files valid
- `1` - One or more files invalid
- `2` - Error (missing schema, dependency, etc.)

Requires `python3-jsonschema` (apt install python3-jsonschema).

### File Permissions

`secrets.yaml` is set to `600` (owner read/write only) after decryption, both by `make decrypt` and the post-checkout git hook. This prevents accidental exposure of plaintext secrets.

### Git Hooks
- **pre-commit**: Auto-encrypts secrets.yaml, blocks plaintext commits
- **post-checkout**: Auto-decrypts secrets.yaml.enc (sets 600 permissions)
- **post-merge**: Delegates to post-checkout

## Reference Resolution

Config files use references (FK) to secrets.yaml:
```yaml
# nodes/srv1.yaml
api_token: srv1  # Resolves to secrets.api_tokens.srv1
```

iac-driver's ConfigResolver resolves all references at runtime and generates flat tfvars for tofu.

## Related Repos

| Repo | Uses |
|------|------|
| iac-driver | All entities - resolves config for tofu (tfvars.json) and ansible (ansible-vars.json) |
| tofu | Receives flat tfvars from iac-driver (no direct config access) |
| ansible | Receives resolved vars from iac-driver; uses `hosts/*.yaml` for host configuration |
| bootstrap | Clones and sets up config |

## Migration from tfvars

Old structure (v0.3.x):
- `hosts/*.tfvars` → `hosts/*.yaml` + `nodes/*.yaml` + `secrets.yaml`
- `envs/*/terraform.tfvars` → `envs/*.yaml` (flattened)

## License

Apache 2.0
