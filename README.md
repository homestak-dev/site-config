# site-config

Site-specific configuration for [homestak](https://github.com/homestak-dev) deployments.

## Overview

Configuration entities:
- **hosts/** - Physical machines (SSH access, storage, network)
- **nodes/** - PVE instances (API access)
- **postures/** - Security postures (SSH, sudo, auth model)
- **specs/** - Node specifications (what to become: packages, users, services)
- **presets/** - VM size presets (cores, memory, disk)
- **manifests/** - Deployment topologies (graph-based node orchestration)

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
  # Key identifiers use user@host convention
  admin@workstation: "ssh-rsa YOUR-KEY-HERE admin@workstation"
EOF

# Encrypt secrets
make encrypt
```

## Structure

```
site-config/
├── site.yaml              # Non-sensitive defaults (timezone, packages)
├── secrets.yaml           # ALL secrets (encrypted with SOPS)
├── hosts/                 # Physical machines
│   └── {name}.yaml        # SSH access, network, storage
├── nodes/                 # PVE instances
│   └── {name}.yaml        # API endpoint, token ref, IP, datastore
├── postures/              # Security postures
│   └── {name}.yaml        # SSH, sudo, auth model settings
├── specs/                 # Node specifications
│   ├── base.yaml          # General-purpose VM (user, packages, timezone)
│   └── pve.yaml           # PVE hypervisor (proxmox packages, services)
├── presets/               # Size presets (vm- prefix)
│   └── vm-{size}.yaml     # cores, memory, disk
└── manifests/             # Deployment topologies
    └── {name}.yaml        # Graph-based node orchestration
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
  # Key identifiers use user@host convention (matches key comment)
  admin@workstation: "ssh-rsa ... admin@workstation"
```

### hosts/{name}.yaml
```yaml
# Primary key derived from filename: pve.yaml -> pve
access:
  ssh_user: root
  authorized_keys:
    - admin@workstation           # FK -> secrets.ssh_keys["admin@workstation"]
```

### nodes/{name}.yaml
```yaml
# Primary key derived from filename: pve.yaml -> pve
host: pve                         # FK -> hosts/pve.yaml
api_endpoint: "https://localhost:8006"
api_token: pve                    # FK -> secrets.api_tokens.pve
ip: "10.0.0.1"                    # Node IP for SSH access
```

### presets/vm-{size}.yaml
```yaml
# Presets: vm-xsmall (1c/1G/8G), vm-small (2c/2G/10G), vm-medium (2c/4G/20G),
#          vm-large (4c/8G/40G), vm-xlarge (8c/16G/64G)
cores: 2
memory: 4096    # MB
disk: 20        # GB
```

### specs/{name}.yaml
```yaml
# Specifications define "what a node should become"
schema_version: 1

access:
  posture: dev                     # FK -> postures/dev.yaml
  users:
    - name: homestak
      sudo: true
      ssh_keys:
        - ssh_keys.admin@host      # FK -> secrets.ssh_keys

platform:
  packages:
    - htop
    - curl

config:
  timezone: America/Denver
```

### manifests/{name}.yaml
```yaml
# Graph-based deployment topology
schema_version: 2
name: n1-basic
pattern: flat
nodes:
  - name: edge
    type: vm
    spec: base                     # FK -> specs/base.yaml
    preset: vm-small               # FK -> presets/vm-small.yaml
    image: debian-12
    vmid: 99001
```

## Deploy Pattern

Manifests define deployment topologies. Use verb commands via iac-driver:

```bash
# Deploy infrastructure from manifest
cd ../iac-driver && ./run.sh create -M n1-basic -H father

# Full roundtrip: create, verify SSH, destroy
./run.sh test -M n2-quick -H father

# Tear down
./run.sh destroy -M n1-basic -H father --yes
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

## Third-Party Acknowledgments

This project relies on excellent open-source tools:

| Tool | Purpose |
|------|---------|
| [SOPS](https://github.com/getsops/sops) | Secrets encryption with structured file support |
| [age](https://github.com/FiloSottile/age) | Simple, modern encryption backend |

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
