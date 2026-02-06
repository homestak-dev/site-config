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
├── envs/                  # Deployment topology templates (node-agnostic)
│   ├── dev.yaml           # env-specific config, node at deploy time
│   ├── test.yaml
│   ├── k8s.yaml
│   ├── ansible-test.yaml  # Ansible role validation
│   └── nested-pve.yaml    # Integration testing
└── manifests/             # Recursive scenario manifests (v0.39+)
    ├── n2-quick.yaml      # 2-level nested PVE test
    └── n3-full.yaml       # 3-level nested PVE test
```

## v2 Structure (v0.45+)

The `v2/` directory contains the next-generation lifecycle configuration for the create → config → run → destroy model. It is self-contained, replicating entities from v1 that are needed for lifecycle phases.

### Unified Node Model

All compute entities (VMs, containers, PVE hosts, k3s nodes) are "nodes" with a common lifecycle:

```
node (abstract)
├── type: pve     → Proxmox VE hypervisor
├── type: vm      → KVM virtual machine
├── type: ct      → LXC container
└── type: k3s     → Kubernetes node (future)
```

**Parent-child topology:**
```
father (pve, physical)
├── dev1 (vm, parent: father)
├── dev2 (ct, parent: father)
└── nested-pve (vm, parent: father)
    └── test1 (vm, parent: nested-pve)
```

### Directory Structure

```
v2/
├── defs/                  # Schema definitions
│   ├── spec.schema.json   # JSON Schema for specifications
│   ├── manifest.schema.json # JSON Schema for v2 manifests
│   └── posture.schema.json # JSON Schema for postures
├── specs/                 # Specifications (what to become)
│   ├── pve.yaml           # PVE host specification
│   └── base.yaml          # Minimal Debian specification
├── postures/              # Security postures with auth model
│   ├── dev.yaml           # network trust
│   ├── stage.yaml         # site_token auth
│   ├── prod.yaml          # node_token auth
│   └── local.yaml         # network trust (on-box)
└── presets/               # Size presets (with vm- prefix)
    ├── vm-xsmall.yaml
    ├── vm-small.yaml
    ├── vm-medium.yaml
    ├── vm-large.yaml
    └── vm-xlarge.yaml
```

**Note:** `v2/nodes/` was removed in v0.46. Node properties (type, spec, preset, image, disk) are now defined inline in manifest v2 `nodes[]` entries.

**Lifecycle coverage:**
- **create**: `v2/presets/` + manifest `nodes[]` (infrastructure provisioning)
- **config**: `v2/specs/` + `v2/postures/` (fetch spec, apply configuration)

**Design rationale:**
- v2 is self-contained, can evolve independently of v1
- `secrets.yaml` remains shared (site-wide sensitive values)
- `presets/` uses `vm-` prefix to allow future preset types (e.g., `network-`)
- Node definitions live in manifests, not standalone files

### v2/specs/{name}.yaml

Specifications define "what a node should become" - packages, services, users, configuration. Consumed by `homestak spec get` (config phase) and `homestak config` (config phase).

Schema: `v2/defs/spec.schema.json`

| Section | Required | Description |
|---------|----------|-------------|
| `schema_version` | Yes | Must be `1` |
| `identity` | No | Hostname/domain, defaults from `HOMESTAK_IDENTITY` |
| `network` | No | Static IP config, omit for DHCP |
| `access` | No | Posture + users, defaults to `dev` posture |
| `platform` | No | Packages + services |
| `config` | No | Type-specific configuration |
| `apply` | No | Trigger settings |

**FK resolution (runtime):**
- `access.posture` → `v2/postures/{value}.yaml`
- `access.users[].ssh_keys[]` → `secrets.yaml → ssh_keys.{value}`

### Auth Model (Config Phase)

Authentication for the config phase ensures nodes are authorized to fetch their specs. The auth method is determined by posture, with optional node-level override.

**Auth methods by posture:**

| Posture | Auth Method | Token Source | Description |
|---------|-------------|--------------|-------------|
| dev | `network` | none | Trust network boundary |
| local | `network` | none | On-box execution |
| stage | `site_token` | `secrets.auth.site_token` | Shared site-wide token |
| prod | `node_token` | `secrets.auth.node_tokens.{name}` | Per-node unique token |

**Flow:**
1. **create**: Token injected via cloud-init (if required by posture)
2. **config**: Node presents token when calling `homestak spec get`
3. **Server**: Validates token before serving spec

**Node-level override:**
```yaml
# v2/nodes/secure-node.yaml
type: vm
spec: base
auth:
  method: node_token  # Override posture default
  token: secure-node  # FK to secrets.auth.node_tokens.secure-node
```

**Posture schema:**

Schema: `v2/defs/posture.schema.json`

```yaml
# v2/postures/stage.yaml
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
- `defaults.domain` - Network domain
- `defaults.ssh_user` - Default SSH user (typically root)
- `defaults.bridge` - Default network bridge
- `defaults.gateway` - Default gateway for static IPs
- `defaults.packages` - Base packages installed on all VMs
- `defaults.pve_remove_subscription_nag` - Remove PVE subscription popup (bool)
- `defaults.packer_release` - Packer release for image downloads (default: `latest`)
- `defaults.spec_server` - Spec server URL for create → config flow (v0.45+, default: empty/disabled)

**Note:** `datastore` was moved to nodes/ in v0.13 - it's now required per-node.

**Packer images:** The `latest` release is the primary source for packer images. Most versioned releases don't include images; automation defaults to `packer_release: latest`. Override with a specific version (e.g., `v0.20`) only when needed.

### secrets.yaml
ALL sensitive values in one file (encrypted):
- `api_tokens.{node}` - Proxmox API tokens
- `passwords.vm_root` - VM root password hash
- `ssh_keys.{user@host}` - SSH public keys (identifier matches key comment)
- `auth.site_token` - Shared token for stage posture (v0.43+)
- `auth.node_tokens.{name}` - Per-node tokens for prod posture (v0.43+)

**Auth tokens (v0.43+):**
```yaml
# secrets.yaml structure for config phase authentication
auth:
  site_token: "shared-secret-for-staging"  # Used by stage posture
  node_tokens:
    dev1: "unique-token-for-dev1"          # Used by prod posture
    dev2: "unique-token-for-dev2"
```

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

**iac-driver usage (v0.36+):** When `--host X` is specified and `nodes/X.yaml` doesn't exist, iac-driver falls back to `hosts/X.yaml` for SSH-only access. This enables provisioning fresh Debian hosts before PVE is installed:
```bash
# Create host config on fresh Debian machine
ssh root@<ip> "cd /usr/local/etc/homestak && make host-config"

# Provision PVE using hosts/ config (no nodes/ yet)
./run.sh --scenario pve-setup --host daughter

# After pve-setup, nodes/daughter.yaml is auto-generated
```

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

Available presets: `xsmall` (1c/1GB/8GB), `small` (2c/2GB/10GB), `medium` (2c/4GB/20GB), `large` (4c/8GB/40GB), `xlarge` (8c/16GB/64GB)

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

### manifests/{name}.yaml (v0.39+)
Manifest definitions for recursive-pve scenarios.
Primary key derived from filename (e.g., `n2-quick.yaml` → `n2-quick`).

**Level modes (v0.41+):**
- **env mode**: `env` FK references envs/ (traditional)
- **vm_preset mode**: `vm_preset` + `vmid` + `image` (simpler, no envs/ dependency)

Schema v1 fields:
- `schema_version` - Always 1 for linear levels format
- `name` - Manifest identifier
- `description` - Human-readable description
- `levels[]` - List of nesting levels:
  - `name` - Level identifier (used in context keys)
  - `env` - FK to envs/ (env mode)
  - `vm_preset` - FK to vms/presets/ (vm_preset mode)
  - `vmid` - Explicit VM ID (required for vm_preset mode)
  - `image` - Image name (required for vm_preset mode, optional override for env mode)
  - `post_scenario` - Scenario to run after level is up (e.g., `pve-setup`)
  - `post_scenario_args` - Arguments for post_scenario
- `settings` - Optional settings:
  - `verify_ssh` - Verify SSH access at each level (default: true)
  - `cleanup_on_failure` - Destroy on failure (default: true)
  - `timeout_buffer` - Extra timeout per level (default: 60)

Built-in v1 manifests: `n1-basic` (1 level), `n2-quick` (2 levels), `n3-full` (3 levels)

Schema v2 fields (v0.46+):
- `schema_version` - Must be 2 for graph-based nodes format
- `name` - Manifest identifier
- `description` - Human-readable description
- `pattern` - Topology shape: `flat` or `tiered`
- `nodes[]` - List of graph nodes:
  - `name` - Node identifier (VM hostname)
  - `type` - Node type: `vm`, `ct`, `pve`
  - `spec` - FK to v2/specs/
  - `preset` - FK to v2/presets/ (vm- prefixed)
  - `image` - Cloud image name
  - `vmid` - Explicit VM ID
  - `disk` - Disk size override
  - `parent` - FK to another node name (null/omitted = root)
  - `execution.mode` - Per-node execution mode (push/pull)
- `settings` - Optional settings (same as v1, plus `on_error`)
  - `on_error` - Error handling: `stop`, `rollback`, `continue` (default: stop)

Built-in v2 manifests: `n1-basic-v2` (flat), `n2-quick-v2` (tiered 2-level), `n3-full-v2` (tiered 3-level)

## Discovery Mechanism

Other homestak tools find site-config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../site-config/` sibling directory (dev workspace)
3. `/usr/local/etc/homestak/` (FHS-compliant bootstrap)

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

## Secrets Management

Only `secrets.yaml` is encrypted - all other files are non-sensitive.

```bash
make setup    # Configure git hooks, check dependencies
make encrypt  # Encrypt secrets.yaml -> secrets.yaml.enc
make decrypt  # Decrypt secrets.yaml.enc -> secrets.yaml
make check    # Show setup status
make validate # Validate YAML syntax + schemas
```

### Schema Validation

The `scripts/validate-schemas.sh` script validates YAML files against JSON schemas:

```bash
# Validate all specs, postures, and v2 manifests
./scripts/validate-schemas.sh

# Validate specific files
./scripts/validate-schemas.sh v2/specs/pve.yaml v2/postures/dev.yaml

# JSON output for CI/scripting
./scripts/validate-schemas.sh --json
```

**Schema mapping:**
| Directory | Schema |
|-----------|--------|
| `v2/specs/*.yaml` | `v2/defs/spec.schema.json` |
| `v2/postures/*.yaml` | `v2/defs/posture.schema.json` |
| `manifests/*.yaml` (v2) | `v2/defs/manifest.schema.json` |

**Exit codes:**
- `0` - All files valid
- `1` - One or more files invalid
- `2` - Error (missing schema, dependency, etc.)

Requires `python3-jsonschema` (apt install python3-jsonschema).

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
