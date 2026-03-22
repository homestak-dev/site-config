# Getting Started

How to set up, validate, and work with the config repo.

## Initial Setup

The config repo is cloned automatically by bootstrap (on installed hosts) or as part of the workspace setup (see `$HOMESTAK_ROOT/dev/meta/docs/getting-started.md`). Once cloned, run setup:

```bash
cd $HOMESTAK_ROOT/config
make setup
```

`make setup` configures git hooks (auto-encrypt/decrypt secrets on
commit/checkout) and checks for the presence of `site.yaml` and
`secrets.yaml`. It also reports whether the optional encryption tools (age,
sops) are installed.

## Installing Encryption Tools

Encryption is optional but recommended for teams or multi-host deployments.
Install before creating local config files (so `make init-secrets` can decrypt):

```bash
sudo make install-deps    # Installs age and sops
```

The age key lives at `~/.config/sops/age/keys.txt`. SOPS configuration in
`.sops.yaml` references the public key for encryption.

## Creating Local Config Files

Two files are gitignored and must be created locally on each machine:

### site.yaml

```bash
make init-site
```

Copies `site.yaml.example` to `site.yaml`. Edit the result to set your
network-specific values:

- `defaults.gateway` -- your router IP
- `defaults.dns_servers` -- your DNS servers
- `defaults.domain` -- your local domain (optional)

All other fields have safe defaults (timezone, bridge, packages, vm_user).

### secrets.yaml

```bash
make init-secrets
```

This command uses a three-step fallback:

1. If `secrets.yaml.enc` exists and an age key is available, decrypts it
2. Otherwise, copies `secrets.yaml.example` as a starting template
3. Sets file permissions to `600` (owner read/write only)

Secrets are populated later by `homestak pve-setup` or manually.

## Generating Host and Node Configs

Run these on each physical machine to create its config files:

```bash
# On a physical host (generates hosts/{hostname}.yaml)
make host-config

# On a PVE host (generates nodes/{hostname}.yaml)
make node-config
```

Both commands gather system inventory automatically:

- `host-config.sh` detects network bridges, ZFS pools, SSH settings, and
  hardware (CPU cores, memory)
- `node-config.sh` detects the PVE API endpoint, default datastore, and node IP

Use `FORCE=1` to overwrite existing files:

```bash
make host-config FORCE=1
make node-config FORCE=1
```

Host and node configs are gitignored because they contain site-specific data.

## Editing Entity Files

Tracked entities (specs, postures, presets, manifests) are checked into git.
Gitignored entities (hosts, nodes, site.yaml, secrets.yaml) are local only,
created by `make host-config`, `make node-config`, `make init-site`, and
`make init-secrets` respectively.

## Validation

```bash
make validate                                    # YAML syntax + JSON schemas
./scripts/validate-schemas.sh                    # Schema validation only
./scripts/validate-schemas.sh --json             # JSON output for CI
make test                                        # Bats tests
make lint                                        # Shellcheck on scripts
```

## Secrets Management

```bash
make encrypt    # secrets.yaml -> secrets.yaml.enc
make decrypt    # secrets.yaml.enc -> secrets.yaml (sets 600 permissions)
make check      # Shows tool versions, key presence, file status
```

Git hooks auto-encrypt on commit and auto-decrypt on checkout/merge when an
age key is available.

## Workflow Summary

```bash
# New deployment
make setup && make init-site && make init-secrets
# Edit site.yaml with your network values
make host-config              # Run on target host
make node-config              # Run on PVE host
make validate

# Ongoing development
make validate && make test && make lint
```
