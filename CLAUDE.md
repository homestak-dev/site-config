# site-config

This file provides guidance to Claude Code when working with this repository.

## Overview

Site-specific configuration for homestak deployments using a normalized 4-entity YAML structure. Separates concerns: physical machines, PVE instances, VM templates, and deployment topologies.

## Entity Model (4NF)

```
┌─────────────┐                     ┌─────────────┐
│   hosts/    │                     │    vms/     │
│ (physical)  │                     │ (templates) │
│  Ansible    │                     │ Tofu/Packer │
└──────┬──────┘                     └──────┬──────┘
       │                                   │
       │ FK: host                          │ FK: vm
       ▼                                   ▼
┌─────────────┐                     ┌─────────────┐
│   nodes/    │◄── -var="node=X" ──│   envs/     │
│  (PVE API)  │    (deploy-time)   │ (templates) │
│    Tofu     │                     │    Tofu     │
└─────────────┘                     └─────────────┘
```

**Note:** Primary keys are derived from filenames (e.g., `hosts/pve.yaml` → identifier is `pve`).
Envs are node-agnostic templates; the target node is specified at deploy time via `-var="node=..."`.
Foreign keys (FK) are explicit references between entities.

## Structure

```
site-config/
├── site.yaml              # Non-sensitive site-wide defaults
├── secrets.yaml           # ALL sensitive values (SOPS encrypted)
├── secrets.yaml.enc       # Encrypted version (committed to private forks)
├── hosts/                 # Physical machines (Ansible domain)
│   └── {name}.yaml        # SSH access (Phase 4: network, storage)
├── nodes/                 # PVE instances (Tofu API access)
│   ├── pve.yaml           # Generic example (localhost:8006)
│   └── nested-pve.yaml    # Nested PVE (parent_node reference)
├── vms/                   # VM templates (Phase 5)
│   └── (future)
└── envs/                  # Deployment topology templates (node-agnostic)
    ├── dev.yaml           # env-specific config, node at deploy time
    ├── test.yaml
    └── k8s.yaml
```

## Entity Definitions

### site.yaml
Non-sensitive defaults inherited by all entities:
- `defaults.timezone`
- `defaults.domain`
- `defaults.datastore`
- `defaults.ssh_user`

### secrets.yaml
ALL sensitive values in one file (encrypted):
- `api_tokens.{node}` - Proxmox API tokens
- `passwords.vm_root` - VM root password hash
- `ssh_keys.{user}` - SSH public keys

### hosts/{name}.yaml
Physical machine configuration (Ansible consumes).
Primary key derived from filename (e.g., `pve.yaml` → `pve`).
- `access.ssh_user` - SSH username
- `access.authorized_keys` - References to secrets.ssh_keys (FK)
- (Phase 4: network, storage, system config)

### nodes/{name}.yaml
PVE instance configuration (Tofu consumes).
Primary key derived from filename (e.g., `pve.yaml` → `pve`).
- `host` - FK to hosts/ (physical machine)
- `parent_node` - FK to nodes/ (for nested PVE, instead of host)
- `api_endpoint` - Proxmox API URL
- `api_token` - Reference to secrets.api_tokens (FK)
- `datastore` - Default storage (optional, falls back to site.yaml)
- `ip` - Node IP for SSH access

### envs/{name}.yaml
Deployment topology template (Tofu consumes).
Primary key derived from filename (e.g., `dev.yaml` → `dev`).
Node-agnostic: target node specified at deploy time via `-var="node=..."`.
- (Phase 5: VM topology, network config)

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

`host-config` gathers: network bridges (vmbr*), ZFS pools, SSH access
`node-config` gathers: PVE API endpoint, datastore (requires PVE installed)

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
# nodes/pve.yaml
api_token: pve  # Resolves to secrets.api_tokens.pve
```

The config-loader module (tofu) or iac-driver resolves these at runtime.

## Related Repos

| Repo | Consumes |
|------|----------|
| iac-driver | `nodes/*.yaml` + `secrets.yaml` for host config |
| tofu | `nodes/*.yaml` + `envs/*.yaml` + `secrets.yaml` for deployments |
| ansible | `hosts/*.yaml` for machine configuration |
| bootstrap | Clones and sets up site-config |

## Migration from tfvars

Old structure (v0.3.x):
- `hosts/*.tfvars` → `hosts/*.yaml` + `nodes/*.yaml` + `secrets.yaml`
- `envs/*/terraform.tfvars` → `envs/*.yaml` (flattened)

## License

Apache 2.0
