# site-config

Site-specific configuration for [homestak](https://github.com/homestak-dev) deployments.

## Overview

Normalized 4-entity configuration structure separating:
- **hosts/** - Physical machines (Ansible)
- **nodes/** - PVE instances (Tofu API access)
- **vms/** - VM templates (Phase 5)
- **envs/** - Deployment topology templates (node-agnostic)

All secrets are centralized in a single encrypted `secrets.yaml` file.

## Quick Start

```bash
# Clone the template
git clone https://github.com/homestak-dev/site-config.git
cd site-config

# Setup encryption
make setup

# On your PVE host: auto-generate config from system inventory
make host-config    # → hosts/{hostname}.yaml
make node-config    # → nodes/{hostname}.yaml

# Create secrets.yaml with your values
cat > secrets.yaml << 'EOF'
api_tokens:
  pve: "root@pam!tofu=YOUR-TOKEN-HERE"

passwords:
  vm_root: "$6$YOUR-HASH-HERE"

ssh_keys:
  admin: "ssh-rsa YOUR-KEY-HERE"
EOF

# Encrypt secrets
make encrypt
```

## Structure

```
site-config/
├── site.yaml              # Non-sensitive defaults (timezone, datastore)
├── secrets.yaml           # ALL secrets (encrypted with SOPS)
├── hosts/                 # Physical machines
│   └── {name}.yaml        # SSH access (Phase 4: network, storage)
├── nodes/                 # PVE instances
│   └── {name}.yaml        # API endpoint, token ref, IP, datastore
└── envs/                  # Deployment topology templates (node-agnostic)
    └── {name}.yaml        # Node specified at deploy time
```

## Schema

Primary keys are derived from filenames (e.g., `nodes/pve.yaml` → `pve`).
Foreign keys (FK) are explicit references between entities.

### site.yaml
```yaml
defaults:
  timezone: America/Denver
  domain: local
  datastore: local-zfs
  ssh_user: root
```

### secrets.yaml
```yaml
api_tokens:
  pve: "root@pam!tofu=..."
passwords:
  vm_root: "$6$..."
ssh_keys:
  admin: "ssh-rsa ..."
```

### nodes/{name}.yaml
```yaml
# Primary key derived from filename: pve.yaml -> pve
host: pve                         # FK -> hosts/pve.yaml
api_endpoint: "https://localhost:8006"
api_token: pve                    # FK -> secrets.api_tokens.pve
ip: "10.0.0.1"                    # Node IP for SSH access
```

### envs/{name}.yaml
```yaml
# Primary key derived from filename: dev.yaml -> dev
# Node-agnostic template - target host specified at deploy time
---
{}
# Phase 5: VM topology definition
```

## Deploy Pattern

Envs are node-agnostic templates. Use iac-driver to deploy:

```bash
cd iac-driver
./run.sh --scenario simple-vm-roundtrip --host pve      # Deploy to pve
./run.sh --scenario simple-vm-roundtrip --host other    # Deploy to different host
```

## Encryption

Only `secrets.yaml` is encrypted - all other config is non-sensitive.

### Setup

1. Install dependencies:
   ```bash
   sudo make install-deps
   ```

2. Generate age key:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

3. Update `.sops.yaml` with your public key

4. Run setup:
   ```bash
   make setup
   ```

### Commands

| Command | Description |
|---------|-------------|
| `make install-deps` | Install age and sops (requires root) |
| `make setup` | Configure git hooks, check dependencies |
| `make host-config` | Generate hosts/{hostname}.yaml from system info |
| `make node-config` | Generate nodes/{hostname}.yaml from PVE info |
| `make encrypt` | Encrypt secrets.yaml |
| `make decrypt` | Decrypt secrets.yaml.enc |
| `make clean` | Remove plaintext secrets.yaml |
| `make check` | Show setup status |
| `make validate` | Validate YAML syntax |

Use `FORCE=1` to overwrite existing config files:
```bash
make host-config FORCE=1
```

## Discovery

Tools find site-config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../site-config/` sibling directory
3. `/opt/homestak/site-config/` (bootstrap default)

## Related Repos

| Repo | Purpose |
|------|---------|
| [bootstrap](https://github.com/homestak-dev/bootstrap) | Entry point - curl\|bash setup |
| [iac-driver](https://github.com/homestak-dev/iac-driver) | Orchestration engine |
| [ansible](https://github.com/homestak-dev/ansible) | Proxmox host configuration |
| [tofu](https://github.com/homestak-dev/tofu) | VM provisioning |
| [packer](https://github.com/homestak-dev/packer) | Custom Debian cloud images |

## License

Apache 2.0
