# config

This file provides guidance to Claude Code when working with this repository.

## Overview

Site-specific configuration for homestak deployments. Separates concerns: physical machines, PVE instances, security postures, size presets, node specifications, and deployment manifests.

## Ecosystem Context

This repo is part of the homestak polyrepo workspace. For project architecture,
development lifecycle, sprint/release process, and cross-repo conventions, see:

- `~/homestak/dev/meta/CLAUDE.md` — primary reference
- `docs/process/` in meta — 7-phase development process
- `docs/standards/claude-guidelines.md` in meta — documentation standards

When working in a scoped session (this repo only), follow the same sprint/release
process defined in meta. Use `/session save` before context compaction and
`/session resume` to restore state in new sessions.

### Agent Boundaries

This agent operates within the following constraints:

- Opens PRs via `homestak-bot`; never merges without human approval
- Runs lint and validation tools only; never executes infrastructure operations
- Never accesses `secrets.yaml`, encryption tooling (`sops`/`age`), or `make decrypt/encrypt`

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
    ├── n2-push.yaml     # 2-level tiered PVE test
    ├── n2-pull.yaml      # Push-mode PVE + pull-mode VM (ST-5)
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

## Quick Reference

```bash
# Setup and initialization
make setup              # Configure git hooks, check dependencies
make init-site          # Create site.yaml from template
make init-secrets       # Decrypt or copy secrets.yaml
sudo make install-deps  # Install age and sops

# Validation and checks
make test               # Run all tests
make lint               # Lint checks
make validate           # Validate YAML syntax + schemas
make check              # Show setup status

# Secrets management
make encrypt            # Encrypt secrets.yaml -> secrets.yaml.enc
make decrypt            # Decrypt secrets.yaml.enc -> secrets.yaml

# Config generation (run on target host)
make host-config        # Generate hosts/{hostname}.yaml from system info
make node-config        # Generate nodes/{hostname}.yaml from PVE info
make host-config FORCE=1  # Force overwrite existing
make node-config FORCE=1  # Force overwrite existing
```

## Discovery Mechanism

Other homestak tools find config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../config/` sibling directory (dev workspace)
3. `~homestak/config/` (bootstrap install)

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

## Documentation

@docs/entity-model.md
@docs/validation.md
