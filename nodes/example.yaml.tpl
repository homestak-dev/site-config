# nodes/example.yaml.tpl - PVE instance configuration template
#
# Copy this file and customize for your PVE instance.
# This is consumed by Tofu for VM provisioning.
#
# Naming: Use the PVE node name (e.g., pve1.yaml)

# PVE node identifier (should match filename without .yaml)
node: mypve

# Reference to physical host (FK -> hosts/)
host: mypve

# Proxmox API endpoint
api_endpoint: "https://mypve.local:8006"

# Reference to API token in secrets.yaml.api_tokens
api_token: mypve      # -> secrets.api_tokens.mypve

# Default storage for VMs
datastore: local-zfs

# For nested PVE (running as a VM), use parent_node instead of host:
# parent_node: physical-pve    # FK -> nodes/
