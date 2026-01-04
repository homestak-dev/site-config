# Example host configuration
# Copy this file to <hostname>.tfvars and fill in real values
# Then run: make encrypt

# Proxmox node name (as shown in PVE web UI)
proxmox_node_name = "pve"

# API endpoint (use hostname or IP)
proxmox_api_endpoint = "https://pve.example.com:8006"

# API token (create in Datacenter > Permissions > API Tokens)
# Format: user@realm!tokenid=secret
proxmox_api_token = "root@pam!tofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Root password hash (generate with: mkpasswd -m sha-512)
# Used for cloud-init VM provisioning
root_password_hash = "$6$rounds=500000$salt$hash..."

# SSH user for iac-driver and tofu provider (default: root)
# Use non-root user with sudo if root SSH is disabled
ssh_user = "root"
