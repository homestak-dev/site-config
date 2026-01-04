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
│   nodes/    │◄────── FK: node ────│   envs/     │
│  (PVE API)  │      (deploy-time)  │ (topology)  │
│    Tofu     │                     │    Tofu     │
└─────────────┘                     └─────────────┘
```

## Structure

```
site-config/
├── site.yaml              # Non-sensitive site-wide defaults
├── secrets.yaml           # ALL sensitive values (SOPS encrypted)
├── secrets.yaml.enc       # Encrypted version (committed to private forks)
├── hosts/                 # Physical machines (Ansible domain)
│   ├── father.yaml        # Network, storage, SSH access
│   └── mother.yaml
├── nodes/                 # PVE instances (Tofu API access)
│   ├── father.yaml        # api_endpoint, api_token ref, datastore
│   ├── mother.yaml
│   └── pve-deb.yaml       # Nested PVE (parent_node reference)
├── vms/                   # VM templates (Phase 5)
│   └── (future)
└── envs/                  # Deployment topologies
    ├── dev.yaml           # node reference, env-specific config
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
Physical machine configuration (Ansible consumes):
- `host` - Machine identifier
- `access.ssh_user` - SSH username
- `access.authorized_keys` - References to secrets.ssh_keys
- (Phase 4: network, storage, system config)

### nodes/{name}.yaml
PVE instance configuration (Tofu consumes):
- `node` - PVE node identifier
- `host` - FK to hosts/ (physical machine)
- `parent_node` - FK to nodes/ (for nested PVE)
- `api_endpoint` - Proxmox API URL
- `api_token` - Reference to secrets.api_tokens
- `datastore` - Default storage

### envs/{name}.yaml
Deployment configuration (Tofu consumes):
- `env` - Environment identifier
- `node` - FK to nodes/ (deployment target)
- `node_ip` - Target node IP (optional)
- (Phase 5: VM topology, network config)

## Discovery Mechanism

Other homestak tools find site-config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../site-config/` sibling directory
3. `/opt/homestak/site-config/` fallback

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
