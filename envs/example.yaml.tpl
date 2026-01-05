# envs/example.yaml.tpl - Deployment environment template
#
# Copy this file and customize for your deployment.
# This is consumed by Tofu for environment-specific configuration.
#
# Naming: Use a descriptive environment name (e.g., dev.yaml, prod.yaml)

# Environment identifier (should match filename without .yaml)
env: myenv

# Reference to target node (FK -> nodes/)
node: mypve           # -> nodes/mypve.yaml

# Node IP address (for SSH access during provisioning)
node_ip: "10.0.0.100"
