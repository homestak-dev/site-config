# Example environment configuration
# Copy this directory to your environment name (dev, k8s, etc.)
# Then copy this file to terraform.tfvars and fill in real values
# Finally run: make encrypt

# Proxmox connection (can reference hosts/ config or specify directly)
proxmox_node_name    = "pve"
proxmox_api_endpoint = "https://pve.example.com:8006"
proxmox_api_token    = "root@pam!tofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# VM defaults for this environment
vm_datastore_id = "local-zfs"

# SSH public keys for VM access (one per line)
ssh_public_keys = <<-EOT
ssh-rsa AAAA... user@host
EOT
