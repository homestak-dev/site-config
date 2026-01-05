# Changelog

## Unreleased

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
