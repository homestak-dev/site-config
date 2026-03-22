# Entity Model

Detailed definitions for each config entity type. Primary keys are derived from
filenames (e.g., `hosts/srv1.yaml` → identifier is `srv1`). Foreign keys (FK) are
explicit YAML references between entities.

## Key Concepts

**Config** vs **spec** — two different kinds of data in this repo:

- **Config** is site-wide operational settings shared across all nodes: network
  (gateway, DNS), timezone, packages, credentials. Lives in `site.yaml` and
  `secrets.yaml`. Answers: "what does this site look like?"
- **Spec** is per-node desired state: what packages, users, services, and security
  posture a specific node should have. Lives in `specs/*.yaml`. Answers: "what
  should this node become?"

Config is the same everywhere. Specs vary per node — a PVE host gets one spec,
a web server VM gets another. The manifest links nodes to specs via FK.

## site.yaml

Non-sensitive defaults inherited by all entities:
- `defaults.timezone` - System timezone (e.g., America/Denver)
- `defaults.domain` - Network domain (optional, blank by default)
- `defaults.host_user` - SSH user for PVE host access (typically root)
- `defaults.vm_user` - User created on VMs via cloud-init (default: homestak)
- `defaults.bridge` - Default network bridge
- `defaults.gateway` - Default gateway for static IPs
- `defaults.packages` - Base packages installed on all VMs
- `defaults.pve_remove_subscription_nag` - Remove PVE subscription popup (bool)
- `defaults.image_release` - Image release tag for downloads (default: `latest`)
- `defaults.server_url` - Server URL for create → config flow (default: empty/disabled)
- `defaults.dns_servers` - DNS servers for VMs and PVE bridge config (list of IPs, default: empty)

**Note:** `datastore` was moved to nodes/ in v0.13 - it's now required per-node.

**Images:** The `latest` release is the primary source for images. Most versioned releases don't include images; automation defaults to `image_release: latest`. Override with a specific version (e.g., `v0.20`) only when needed.

## secrets.yaml

ALL sensitive values in one file (encrypted):
- `api_tokens.{node}` - Proxmox API tokens
- `passwords.vm_root` - VM root password hash
- `ssh_keys.{user@host}` - SSH public keys (identifier matches key comment)
- `auth.signing_key` - HMAC-SHA256 signing key for provisioning tokens (#231)

**Signing key:**
```yaml
# secrets.yaml structure for provisioning token authentication
auth:
  signing_key: "<hex-encoded 256-bit key>"  # Generate: python3 -c "import secrets; print(secrets.token_hex(32))"
```

## hosts/{name}.yaml

Physical machine configuration for SSH access and host management.
Primary key derived from filename (e.g., `srv1.yaml` → `srv1`).

**Core fields:**
- `host` - Hostname (matches filename)
- `domain` - Network domain (extracted from FQDN or resolv.conf)

**Network section:**
- `network.interfaces.{bridge}` - Bridge configurations:
  - `type` - Interface type (bridge)
  - `ports` - Physical ports attached to bridge
  - `address` - IP address with CIDR (e.g., 198.51.100.61/24)
  - `gateway` - Default gateway (if default route uses this bridge)

**Storage section:**
- `storage.zfs_pools[]` - ZFS pool configurations:
  - `name` - Pool name
  - `devices` - Backing devices

**Hardware section:**
- `hardware.cpu_cores` - Number of CPU cores
- `hardware.memory_gb` - Total RAM in GB

**Access section:**
- `access.host_user` - SSH username for host access (default: root)
- `access.ssh_port` - SSH port (default: 22)
- `access.authorized_keys` - References to secrets.ssh_keys by user@host identifier (FK)

**SSH section:**
- `ssh.permit_root_login` - Root login policy (yes/no/prohibit-password)
- `ssh.password_authentication` - Password auth policy (yes/no)

**Git tracking:** Site-specific host configs are excluded from git via `.gitignore`. Generate your host config with `make host-config` on each physical host.

**iac-driver usage (v0.36+):** When `--host X` is specified and `nodes/X.yaml` doesn't exist, iac-driver falls back to `hosts/X.yaml` for SSH-only access. This enables provisioning fresh Debian hosts before PVE is installed:
```bash
# Create host config on fresh Debian machine
ssh root@<ip> "cd ~homestak/config && make host-config"

# Provision PVE using hosts/ config (no nodes/ yet)
./run.sh --scenario pve-setup --host daughter

# After pve-setup, nodes/daughter.yaml is auto-generated
```

## nodes/{name}.yaml

PVE instance configuration for API access.
**Important:** Filename must match the actual PVE node name (check with `pvesh get /nodes`).
Primary key derived from filename (e.g., `srv1.yaml` → `srv1`).
- `host` - FK to hosts/ (physical machine)
- `parent_node` - FK to nodes/ (for nested PVE, instead of host)
- `api_endpoint` - Proxmox API URL
- `api_token` - Reference to secrets.api_tokens (FK)
- `datastore` - Storage for VMs (REQUIRED in v0.13+)
- `ip` - Node IP for SSH access

**Git tracking:** All node configs are excluded from git via `.gitignore`. The operator generates node configs dynamically via `make node-config` on each PVE host.

**Migration (v0.13):** If upgrading from earlier versions, regenerate node configs:
```bash
make node-config FORCE=1
```

## postures/{name}.yaml

Security posture configuration with nested structure and auth model.
Primary key derived from filename (e.g., `dev.yaml` → `dev`).
Referenced by specs via `access.posture:` FK.

Schema: `defs/posture.schema.json`

- `auth.method` - Auth method (vestigial for spec auth, used for posture labeling)
- `ssh.port` - SSH port (default: 22)
- `ssh.permit_root_login` - Root login policy (yes/no/prohibit-password)
- `ssh.password_authentication` - Password auth policy (yes/no)
- `sudo.nopasswd` - Passwordless sudo (bool)
- `fail2ban.enabled` - Enable fail2ban (bool)
- `packages` - Additional packages (merged with site.yaml packages)

Available postures:
- `dev` - Permissive (SSH password auth, sudo nopasswd)
- `stage` - Intermediate (hardened SSH, sudo requires password)
- `prod` - Hardened (no root login, fail2ban enabled)
- `local` - On-box execution (same as dev)

## presets/{name}.yaml

Size presets for VM resource allocation. Uses `vm-` prefix to allow future preset types.
Primary key derived from filename (e.g., `vm-small.yaml` → `vm-small`).
- `cores` - Number of CPU cores
- `memory` - RAM in MB
- `disk` - Disk size in GB

Available presets: `vm-xsmall` (1c/1GB/8GB), `vm-small` (2c/2GB/10GB), `vm-medium` (2c/4GB/20GB), `vm-large` (4c/8GB/40GB), `vm-xlarge` (8c/16GB/80GB)

## manifests/{name}.yaml

Manifest definitions for infrastructure orchestration.
Primary key derived from filename (e.g., `n2-push.yaml` → `n2-push`).

Schema v2 fields:
- `schema_version` - Must be 2 for graph-based nodes format
- `name` - Manifest identifier
- `description` - Human-readable description
- `pattern` - Topology shape: `flat` or `tiered`
- `nodes[]` - List of graph nodes:
  - `name` - Node identifier (VM hostname)
  - `type` - Node type: `vm`, `ct`, `pve`
  - `spec` - FK to specs/
  - `preset` - FK to presets/ (vm- prefixed)
  - `image` - Cloud image name
  - `vmid` - Explicit VM ID
  - `disk` - Disk size override
  - `parent` - FK to another node name (null/omitted = root)
  - `execution.mode` - Per-node execution mode (push/pull)
- `settings` - Optional settings (same as v1, plus `on_error`)
  - `on_error` - Error handling: `stop`, `rollback`, `continue` (default: stop)

Built-in manifests: `n1-push` (flat, push mode), `n1-pull` (flat, pull mode), `n2-push` (tiered 2-level), `n2-pull` (tiered, push-mode PVE + pull-mode VM), `n3-deep` (tiered 3-level)

## Specs

### specs/{name}.yaml

Specifications define "what a node should become" - packages, services, users, configuration. Consumed by `homestak spec get` (config phase) and `./run.sh config` (config phase).

Schema: `defs/spec.schema.json`

| Section | Required | Description |
|---------|----------|-------------|
| `schema_version` | Yes | Must be `1` |
| `identity` | No | Hostname/domain, defaults from hostname and site.yaml |
| `network` | No | Static IP config, omit for DHCP |
| `access` | No | Posture + users, defaults to `dev` posture |
| `platform` | No | Packages + services |
| `config` | No | Type-specific configuration |
| `run` | No | Run phase convergence settings |

**FK resolution (runtime):**
- `access.posture` → `postures/{value}.yaml`
- `access.users[].ssh_keys[]` → `secrets.yaml → ssh_keys.{value}`

**SSH key default:** When `ssh_keys` is omitted from a spec's user entry, all keys from `secrets.ssh_keys` are injected automatically. Explicit `ssh_keys[]` entries restrict injection to only the listed keys.

**Available specs:**

| Spec | Purpose |
|------|---------|
| `base` | General-purpose VM: user with sudo, ssh keys, packages, timezone |
| `pve` | PVE hypervisor: proxmox packages, services, PVE config |

### Auth Model (Config Phase, #231)

Authentication for the config phase uses HMAC-SHA256 provisioning tokens. ConfigResolver mints a token per-VM carrying the node identity and spec FK. The server verifies the signature against `secrets.auth.signing_key`.

**Token flow:** ConfigResolver → `auth_token` in tfvars → cloud-init `HOMESTAK_TOKEN` → server `verify_provisioning_token()`

**Note:** Posture files still contain `auth.method` (network/site_token/node_token) which is used for SSH/sudo/security settings but no longer drives spec authentication.

**Posture schema:**

Schema: `defs/posture.schema.json`

```yaml
# postures/stage.yaml
auth:
  method: site_token

ssh:
  port: 22
  permit_root_login: "prohibit-password"
  password_authentication: "no"

sudo:
  nopasswd: false

fail2ban:
  enabled: true

packages:
  - net-tools
```

## Reference Resolution

Config files use references (FK) to secrets.yaml:
```yaml
# nodes/srv1.yaml
api_token: srv1  # Resolves to secrets.api_tokens.srv1
```

iac-driver's ConfigResolver resolves all references at runtime and generates flat tfvars for tofu.

## Unified Node Model

All compute entities (VMs, containers, PVE hosts, k3s nodes) are "nodes" with a common lifecycle:

```
node (abstract)
├── type: pve     → Proxmox VE hypervisor
├── type: vm      → KVM virtual machine
├── type: ct      → LXC container
└── type: k3s     → Kubernetes node (future)
```

Node properties (type, spec, preset, image, disk) are defined inline in manifest `nodes[]` entries.

## Lifecycle Coverage

Configuration for the create → config → run → destroy lifecycle model. Previously in `v2/`, now consolidated at the top level.

- **create**: `presets/` + manifest `nodes[]` (infrastructure provisioning)
- **config**: `specs/` + `postures/` (fetch spec, apply configuration)
