# Changelog

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
