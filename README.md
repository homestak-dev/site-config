# site-config

Site-specific configuration for [homestak](https://github.com/homestak-dev) deployments.

## Overview

Normalized 4-entity configuration structure separating:
- **hosts/** - Physical machines (Ansible)
- **nodes/** - PVE instances (Tofu API access)
- **vms/** - VM templates (future)
- **envs/** - Deployment topologies

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

# Or create configuration manually
cp hosts/example.yaml.tpl hosts/mypve.yaml
cp nodes/example.yaml.tpl nodes/mypve.yaml
cp envs/example.yaml.tpl envs/dev.yaml

# Create secrets.yaml with your values
cat > secrets.yaml << 'EOF'
api_tokens:
  mypve: "root@pam!tofu=YOUR-TOKEN-HERE"

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
│   └── mypve.yaml         # SSH access, (future: network, storage)
├── nodes/                 # PVE instances
│   └── mypve.yaml         # API endpoint, token ref, datastore
└── envs/                  # Deployment configs
    └── dev.yaml           # Node reference, env-specific settings
```

## Entity Relationships

```
secrets.yaml ─────┐
                  │ (token refs)
site.yaml ────────┼───> nodes/*.yaml ◄──── envs/*.yaml
                  │          │
                  │          │ FK: host
                  │          ▼
                  └───> hosts/*.yaml
```

## Encryption

Only `secrets.yaml` is encrypted - all other config is non-sensitive.

### Setup

1. Install dependencies:
   ```bash
   apt install age
   # Install sops from https://github.com/getsops/sops/releases
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

## Entity Files

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
  mypve: "root@pam!tofu=..."
passwords:
  vm_root: "$6$..."
ssh_keys:
  admin: "ssh-rsa ..."
```

### nodes/mypve.yaml
```yaml
node: mypve
host: mypve
api_endpoint: "https://mypve.local:8006"
api_token: mypve      # References secrets.api_tokens.mypve
datastore: local-zfs
```

### envs/dev.yaml
```yaml
env: dev
node: mypve           # References nodes/mypve.yaml
node_ip: "10.0.0.100"
```

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
