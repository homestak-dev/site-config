# Architecture

Design rationale for the config entity model, layered merge strategy, and role
in the broader homestak pipeline.

## Entity Model: Filenames as Keys

Every config entity uses its filename as its primary key. `hosts/srv1.yaml` has
the identifier `srv1`; `presets/vm-small.yaml` has the identifier `vm-small`.
This convention eliminates the class of bugs where a file's contents disagree
with its identity. It also makes the config directory browsable at a glance --
`ls hosts/` lists every known physical machine without parsing YAML.

Foreign keys are explicit YAML references between entities. A node file
references its host:

```yaml
# nodes/srv1.yaml
host: srv1              # FK -> hosts/srv1.yaml
api_token: srv1         # FK -> secrets.api_tokens.srv1
```

iac-driver's ConfigResolver resolves these references at runtime. The config
repo itself stores only the raw YAML; resolution happens downstream.

## Layered Merge Order

Configuration is resolved in layers, with later layers overriding earlier ones:

1. **site.yaml** -- site-wide defaults (gateway, dns, timezone, packages, bridge)
2. **Entity files** -- hosts/, nodes/, specs/, postures/, presets/
3. **secrets.yaml** -- sensitive values (API tokens, SSH keys, signing key)

This layering means a site operator edits `site.yaml` once for network-wide
defaults (gateway, DNS servers, timezone). Individual entities inherit those
defaults and only override what differs. A node that needs a non-standard
datastore sets it in its own file; everything else comes from the site layer.

The merge is not performed by the config repo. ConfigResolver in iac-driver
loads all layers, resolves foreign keys, and produces flat structures for tofu
(tfvars.json) and ansible (ansible-vars.json).

## Why Secrets Are Separate

`secrets.yaml` is isolated from the rest of the config for two reasons:

1. **Encryption at rest.** Secrets are encrypted with SOPS + age into
   `secrets.yaml.enc` for safe storage in git. The plaintext `secrets.yaml` is
   gitignored and only exists on machines that have the age decryption key.
   Git hooks auto-encrypt on commit and auto-decrypt on checkout.

2. **Different access pattern.** Most config files are safe to view and share.
   Secrets contain API tokens, password hashes, SSH keys, and the HMAC signing
   key used for provisioning tokens. Keeping them in a single file with `600`
   permissions makes access control straightforward.

## Why Presets Exist

Presets define VM resource allocations (cores, memory, disk) as reusable
profiles. Without presets, every manifest node would inline its resource
values, leading to duplication and drift. With presets, a manifest references
`preset: vm-small` and gets `2c/2GB/10GB` everywhere.

The `vm-` prefix allows future preset types (e.g., `ct-` for containers).
Available presets:

| Preset | Cores | Memory | Disk |
|--------|-------|--------|------|
| vm-xsmall | 1 | 1 GB | 8 GB |
| vm-small | 2 | 2 GB | 10 GB |
| vm-medium | 2 | 4 GB | 20 GB |
| vm-large | 4 | 8 GB | 40 GB |
| vm-xlarge | 8 | 16 GB | 80 GB |

## Why Postures Exist

Postures decouple security policy from node identity. A spec declares what a
node should become (packages, services, users); a posture declares how it
should be secured (SSH hardening, sudo policy, fail2ban). The same `base` spec
can reference `posture: dev` in a lab environment and `posture: prod` in
production, without duplicating the spec.

Postures are referenced by specs via `access.posture` FK. Available postures
range from `dev` (permissive SSH, passwordless sudo) to `prod` (no root login,
fail2ban enabled).

## The Config Pipeline

Config does not execute infrastructure operations. It is a passive data store
that feeds into iac-driver's ConfigResolver:

```
config/                         iac-driver                      consumers
├── site.yaml   ──┐             ┌──────────────────┐
├── hosts/      ──┤  resolve    │ ConfigResolver    │  tfvars   ──> tofu
├── nodes/      ──┤────────────>│ - Load YAML       │     .json
├── specs/      ──┤             │ - Merge layers    │
├── postures/   ──┤             │ - Resolve FKs     │  ansible  ──> ansible
├── presets/    ──┤             │ - Mint tokens     │     -vars
├── manifests/  ──┘             └──────────────────┘     .json
└── secrets.yaml
```

ConfigResolver performs the following:

1. Loads site.yaml defaults
2. Loads entity files referenced by the manifest
3. Resolves foreign keys (host, posture, preset, api_token, ssh_keys)
4. Merges layers (site defaults < entity values < secrets)
5. Mints HMAC provisioning tokens for VMs (using `secrets.auth.signing_key`)
6. Outputs flat JSON for tofu (VM provisioning) and ansible (host configuration)

The config repo's only executable logic is the generation scripts
(`host-config.sh`, `node-config.sh`) that gather system inventory into YAML,
and the validation scripts that check YAML syntax and JSON schemas.

## Config Discovery

Other homestak tools locate config via `$HOMESTAK_ROOT/config`. `$HOMESTAK_ROOT` defaults to `$HOME` — on installed hosts this resolves to `~homestak/config/`, on dev workstations set it to your workspace root.

This means the same tools work in both development (polyrepo workspace) and
production (bootstrap-installed) environments without configuration changes.
