# site-config

This file provides guidance to Claude Code when working with this repository.

## Overview

Site-specific configuration template for homestak deployments. This is a **public template repo** - users clone/fork it and add their own secrets.

## Structure

```
site-config/
├── .sops.yaml              # Encryption config (user updates with their key)
├── .gitignore              # Ignores real secrets by default
├── .githooks/              # Auto encrypt/decrypt hooks
├── Makefile                # setup, decrypt, encrypt, clean, check
├── hosts/                  # Per-host Proxmox credentials
│   └── example.tfvars.tpl  # Template with placeholder values
└── envs/                   # Per-environment tofu config
    └── example/
        └── terraform.tfvars.tpl
```

## Key Concepts

### Template vs Real Files

- `*.tpl` files are templates with placeholder values (committed)
- `*.tfvars` files contain real secrets (gitignored)
- `*.tfvars.enc` files are encrypted secrets (gitignored by default)

### Discovery Mechanism

Other homestak tools find site-config via:
1. `$HOMESTAK_SITE_CONFIG` environment variable
2. `../site-config/` sibling directory
3. `/opt/homestak/site-config/` fallback

### Encryption

- Uses SOPS + age (same as iac-driver and tofu)
- User must update `.sops.yaml` with their own age public key
- Git hooks auto-encrypt on commit, auto-decrypt on checkout

## Common Commands

```bash
make setup    # Configure git hooks, show key setup instructions
make encrypt  # Encrypt *.tfvars to *.tfvars.enc
make decrypt  # Decrypt *.tfvars.enc to *.tfvars
make check    # Show setup status
```

## User Workflow

1. Clone this repo
2. Generate age key (`age-keygen`)
3. Update `.sops.yaml` with public key
4. Copy templates to real files
5. Fill in actual values
6. `make encrypt`
7. (Optional) Remove `.gitignore` rules and commit encrypted files to private fork

## Related Repos

| Repo | Relationship |
|------|--------------|
| iac-driver | Reads `hosts/*.tfvars` for Proxmox credentials |
| tofu | Reads `envs/*/terraform.tfvars` for environment config |
| bootstrap | Clones and sets up site-config |

## Security Notes

- Never commit plaintext `*.tfvars` files
- The `.gitignore` blocks both plaintext AND encrypted by default
- Users who want to version encrypted secrets must modify `.gitignore`
- Pre-commit hook validates no plaintext is staged

## License

Apache 2.0
