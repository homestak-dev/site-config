# Changelog

## Unreleased

### Added
- Add `manifests/` directory for recursive-pve scenario configuration (#114)
  - `n2-quick.yaml`: 2-level nested PVE test manifest
  - `n3-full.yaml`: 3-level nested PVE test manifest
  - Schema v1: Linear levels array with env, image, post_scenario support

## v0.36 - 2026-01-20

### Documentation
- Document iac-driver hosts/ fallback resolution in CLAUDE.md
  - `--host X` now falls back to `hosts/X.yaml` when `nodes/X.yaml` doesn't exist
  - Enables provisioning fresh Debian hosts before PVE is installed

## v0.32 - 2026-01-19

### Added
- Add `--help` and `--force` flags to host-config.sh and node-config.sh (#36)
- Scripts now support both CLI flags and environment variables (FORCE=1)

## v0.31 - 2026-01-19

- Release alignment with homestak v0.31

## v0.30 - 2026-01-18

- Release alignment with homestak v0.30

## v0.29 - 2026-01-18

- Release alignment with homestak v0.29

## v0.28 - 2026-01-18

- Release alignment with homestak v0.28

## v0.27 - 2026-01-17

- Release alignment with homestak v0.27

## v0.26 - 2026-01-17

- Release alignment with homestak v0.26

## v0.25 - 2026-01-16

- Release alignment with homestak v0.25

## v0.24 - 2026-01-16

### Added

- Add `hosts/.gitkeep` to ensure directory structure is tracked (#16)

## v0.18 - 2026-01-13

- Release alignment with homestak v0.18

## v0.17 - 2026-01-11

### Added
- host-config.sh: Domain extraction from FQDN or resolv.conf (#31)
- host-config.sh: Hardware section with cpu_cores and memory_gb (#31)
- host-config.sh: SSH section with permit_root_login and password_authentication (#31)
- node-config.sh: IP extraction from vmbr0 interface (#32)
- node-config.sh: ssh_user comment noting site.yaml default (#32)

### Changed
- Gitignore `hosts/*.yaml` (matches `nodes/*.yaml` pattern)
- API token renamed from `tofu` to `homestak` for branding consistency (#15)

### Documentation
- CLAUDE.md: Full hosts/{name}.yaml schema with all sections (#13)
- CLAUDE.md: Updated Config Generation section with new fields

## v0.16 - 2026-01-11

- Release alignment with homestak v0.16

## v0.13 - 2026-01-10

### Features

- Add `postures/` directory for security posture definitions
  - `dev.yaml` - Permissive (SSH password auth, sudo nopasswd)
  - `prod.yaml` - Hardened (no root login, fail2ban enabled)
  - `local.yaml` - On-box execution posture
- Extend `site.yaml` with new defaults:
  - `packages` - Base packages for all VMs
  - `pve_remove_subscription_nag` - Remove PVE subscription popup

### Changes

- Add `posture` FK to all envs (references postures/)
- Move `datastore` from site defaults to nodes/ (now required per-node)
- Add `hosts/pve.yaml` template with local_user example

### Documentation

- Update CLAUDE.md entity model with postures
- Document posture schema and resolution order

## v0.12 - 2025-01-09

- Release alignment with homestak-dev v0.12

## v0.11 - 2026-01-08

- Release alignment with iac-driver v0.11

## v0.10 - 2026-01-08

### Documentation

- Add third-party acknowledgments for SOPS and age
- Improve Deploy Pattern examples with practical use cases
- Use `homestak` CLI in examples (vs raw iac-driver commands)
- Clarify node-agnostic env concept
- Add caution for destructive commands (pending confirmation prompt)

### Housekeeping

- Update terminology: E2E → integration testing
- Add LICENSE file (Apache 2.0)
- Add standard repository topics
- Enable secret scanning and Dependabot

## v0.9 - 2026-01-07

### Features

- Use `debian-13-pve` image for nested PVE env (faster deployment)

### Documentation

- Update scenario name: `simple-vm-roundtrip` → `vm-roundtrip`

## v0.8 - 2026-01-06

### Changes

- Exclude site-specific node configs from git tracking (closes #14)
  - `nodes/*.yaml` now gitignored (except `nested-pve.yaml` for E2E tests)
  - Site-specific configs generated via `make node-config`
- Remove deprecated tfvars entries from `.gitignore` (closes #19)
  - Migration to YAML complete, no tfvars files remain
- Secrets audit: all entries in `secrets.yaml` confirmed in use

### Documentation

- Update CLAUDE.md with git tracking conventions for node configs

## v0.7 - 2026-01-06

### Features

- Add `gateway` field to vms schema for static IP configurations (closes #17)

### Changes

- Remove generic `pve.yaml` that caused confusion with real hosts (closes #18)
- Update CLAUDE.md examples to use `father` instead of `pve`

## v0.6 - 2026-01-06

### Phase 5: VM Templates

- Add `vms/` entity for declarative VM definitions
- Add `vms/presets/` with size presets: xsmall, small, medium, large, xlarge
- Add `vms/nested-pve.yaml` and `vms/test.yaml` templates
- Add `vmid_base` and `vms[]` fields to envs/*.yaml
- Template inheritance: preset → template → instance overrides

### Conventions

- Adopt `user@host` convention for ssh_keys identifiers (closes #11)
  - Self-documenting: identifier matches key comment
  - Clear provenance: shows which machine the key is from

### Schema Normalization

- **Breaking:** Primary keys now derived from filename (removed redundant `host:`, `node:`, `env:` fields)
- **Breaking:** Envs are now node-agnostic templates (removed `node:` field from envs/*.yaml)
- Moved `node_ip` from envs to `ip` field in nodes/*.yaml
- Renamed `pve-deb` to `nested-pve` for clarity
- Removed site-specific examples (father, mother) from public template
- Deleted obsolete .tpl template files

### Deploy Pattern

Envs no longer specify target node. Host is specified at deploy time via iac-driver:

```bash
./run.sh --scenario simple-vm-roundtrip --host pve
```

## v0.5.0-rc1 - 2026-01-04

Consolidated pre-release with full tooling.

### Highlights

- make install-deps for automated setup
- make host-config / node-config for system inventory
- SOPS + age encryption for secrets

### Changes

- Documentation improvements

## v0.3.0 - 2026-01-04

### Features

- Add `make install-deps` to install age and sops automatically
  - age via apt
  - sops v3.11.0 via .deb from GitHub releases
  - Idempotent (skips if already installed)

## v0.2.0 - 2026-01-04

### Features

- Add `make host-config` to auto-generate hosts/*.yaml from system inventory
- Add `make node-config` to auto-generate nodes/*.yaml from PVE info
- Gathers network bridges, ZFS pools, API endpoints, datastores
- Won't overwrite existing files (use `FORCE=1` to override)

## v0.1.0 - 2026-01-04

Initial release - site-specific configuration template.

### Features

- Public template repository for homestak deployments
- SOPS + age encryption for secrets
- Git hooks for auto encrypt/decrypt
- Host configuration templates (`hosts/*.tfvars`)
- Environment configuration templates (`envs/*/terraform.tfvars`)

### Configuration

- `ssh_user` - SSH user for iac-driver and tofu provider
- `proxmox_node_name` - Proxmox node name
- `proxmox_api_endpoint` - API endpoint URL
- `proxmox_api_token` - API token for authentication
- `root_password_hash` - Hashed root password for VMs
