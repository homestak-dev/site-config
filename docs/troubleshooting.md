# Troubleshooting

Common issues when working with the config repo and how to resolve them.

## Encryption/Decryption Issues

**`make decrypt` fails with "No age key found"** -- The age private key must exist
at `~/.config/sops/age/keys.txt`. Generate one with:
```bash
age-keygen -o ~/.config/sops/age/keys.txt
```
Then update `.sops.yaml` with the public key and re-encrypt with `make encrypt`.

**`make encrypt` fails with no recipients** -- SOPS reads recipients from `.sops.yaml`.
Verify the `age:` field under `creation_rules` contains a valid public key.

**`secrets.yaml` starts with `sops:` instead of real values** -- The file is still
encrypted. Run `make decrypt` to restore plaintext. If decryption fails, your local
age key may not match the one used to encrypt (the public key in `.sops.yaml` must
correspond to your private key in `keys.txt`).

## Schema Validation Failures

**`make validate` reports errors** -- Validation checks `specs/`, `postures/`, and
`manifests/` against JSON schemas in `defs/`. Common causes:

- **Missing required fields** -- specs need `schema_version: 1`; v2 manifests need
  `schema_version`, `name`, `nodes[]`, and `pattern`.
- **Wrong YAML types** -- booleans like `sudo.nopasswd` must be `true`/`false`, not
  strings. SSH settings like `permit_root_login` must be quoted (`"yes"`, `"no"`).
- **FK references to nonexistent files** -- a manifest referencing `spec: custom`
  passes schema validation but fails at runtime if `specs/custom.yaml` is missing.

**"python3-jsonschema not installed"** -- Run `sudo apt install python3-jsonschema`.
Without it, `make validate` checks YAML syntax only and skips schema checks.

## Init Issues

**`make init-site` vs `make init-secrets`**

| Target | Creates | Source |
|--------|---------|--------|
| `make init-site` | `site.yaml` | `site.yaml.example` |
| `make init-secrets` | `secrets.yaml` | `secrets.yaml.enc` (preferred) or `.example` |

`make init-secrets` decrypts `.enc` if sops and an age key are available; otherwise
it copies the `.example` template with empty placeholders.

**"already exists. Nothing to do."** -- Both targets are idempotent. Delete the
existing file first to recreate: `rm site.yaml && make init-site`.

**What the `.example` templates contain** -- `site.yaml.example` has non-sensitive
defaults (gateway, dns_servers, timezone, packages). `secrets.yaml.example` has empty
placeholders for `api_tokens`, `passwords`, `ssh_keys`, and `auth.signing_key` --
most are auto-populated by `homestak pve-setup`.

## Missing Entity Files

**"Host not found" / "Node not found" from iac-driver** -- The driver resolves
`--host <name>` by looking for `nodes/<name>.yaml` (PVE) or `hosts/<name>.yaml`
(SSH-only fallback). Generate them on the target host:
```bash
cd ~/config && make host-config   # hosts/{hostname}.yaml
cd ~/config && make node-config   # nodes/{hostname}.yaml (PVE hosts only)
```
Use `FORCE=1` to overwrite existing files. Both are gitignored -- generated
per-machine and not shared via the repository.

## Git Hook Issues

**Auto-encrypt on commit fails** -- The pre-commit hook auto-encrypts `secrets.yaml`
when changes are detected. It requires `sops`, a valid `.sops.yaml`, and an age key.
Fix: run `sudo make install-deps` and verify your age key matches `.sops.yaml`.

**Secrets committed unencrypted** -- The git hooks are not installed. Run:
```bash
make setup
```
This sets `core.hooksPath` to `.githooks/`, which includes a pre-commit hook that
blocks plaintext `secrets.yaml` from being staged.

**Hooks not running after a fresh clone** -- Git does not activate custom hooks
automatically. Always run `make setup` after cloning. Verify with
`git config core.hooksPath` (expected output: `.githooks`).
