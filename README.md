# site-config

Site-specific configuration template for [homestak](https://github.com/homestak-dev) deployments.

## Overview

This repository provides a template structure for managing encrypted credentials and environment-specific configuration. Clone or fork this repo to store your site's secrets.

## Quick Start

```bash
# Clone the template
git clone https://github.com/homestak-dev/site-config.git
cd site-config

# Setup encryption
make setup

# Copy templates and fill in your values
cp hosts/example.tfvars.tpl hosts/mypve.tfvars
# Edit hosts/mypve.tfvars with real values

cp -r envs/example envs/dev
cp envs/dev/terraform.tfvars.tpl envs/dev/terraform.tfvars
# Edit envs/dev/terraform.tfvars with real values

# Encrypt your secrets
make encrypt

# (Optional) Commit encrypted secrets to private fork
# Remove *.enc lines from .gitignore first
```

## Structure

```
site-config/
├── hosts/                  # Per-host Proxmox credentials
│   ├── example.tfvars.tpl  # Template (copy and rename)
│   └── mypve.tfvars        # Your host config (gitignored)
│
└── envs/                   # Per-environment tofu config
    ├── example/            # Template environment
    │   └── terraform.tfvars.tpl
    └── dev/                # Your environment (copy from example)
        └── terraform.tfvars
```

## Encryption

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

### First-Time Setup

1. Install dependencies:
   ```bash
   apt install age
   # Install sops from https://github.com/getsops/sops/releases
   ```

2. Generate an age key:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

3. Update `.sops.yaml` with your public key:
   ```bash
   grep "public key:" ~/.config/sops/age/keys.txt
   # Copy the key and replace placeholder in .sops.yaml
   ```

4. Run setup:
   ```bash
   make setup
   ```

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make setup` | Configure git hooks, check dependencies |
| `make encrypt` | Encrypt all plaintext files to `.enc` |
| `make decrypt` | Decrypt all `.enc` files to plaintext |
| `make clean` | Remove plaintext files (keeps `.enc`) |
| `make check` | Verify encryption setup |

## Discovery

Other homestak tools find site-config automatically:

1. `$HOMESTAK_SITE_CONFIG` environment variable (if set)
2. `../site-config/` sibling directory
3. `/opt/homestak/site-config/` (bootstrap default)

## Committing Encrypted Secrets

By default, `.gitignore` blocks both plaintext AND encrypted files (this is a public template).

To commit encrypted secrets to a private fork:

1. Remove these lines from `.gitignore`:
   ```
   *.tfvars.enc
   *.yaml.enc
   *.json.enc
   ```

2. Add and commit your encrypted files:
   ```bash
   git add hosts/*.enc envs/*/*.enc
   git commit -m "Add encrypted site configuration"
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
