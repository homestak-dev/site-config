# Schema Validation

The `scripts/validate-schemas.sh` script validates YAML files against JSON schemas:

```bash
# Validate all specs, postures, and manifests
./scripts/validate-schemas.sh

# Validate specific files
./scripts/validate-schemas.sh specs/pve.yaml postures/dev.yaml

# JSON output for CI/scripting
./scripts/validate-schemas.sh --json
```

## Schema Mapping

| Directory | Schema |
|-----------|--------|
| `specs/*.yaml` | `defs/spec.schema.json` |
| `postures/*.yaml` | `defs/posture.schema.json` |
| `manifests/*.yaml` (v2) | `defs/manifest.schema.json` |

## Exit Codes

- `0` - All files valid
- `1` - One or more files invalid
- `2` - Error (missing schema, dependency, etc.)

Requires `python3-jsonschema` (apt install python3-jsonschema).

## File Permissions

`secrets.yaml` is set to `600` (owner read/write only) after decryption, both by `make decrypt` and the post-checkout git hook. This prevents accidental exposure of plaintext secrets.

## Git Hooks

- **pre-commit**: Auto-encrypts secrets.yaml, blocks plaintext commits
- **post-checkout**: Auto-decrypts secrets.yaml.enc (sets 600 permissions)
- **post-merge**: Delegates to post-checkout
