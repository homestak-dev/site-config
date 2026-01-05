# site-config Makefile
# Secrets management for homestak deployments
#
# Structure:
#   secrets.yaml     - ALL sensitive values (encrypted)
#   site.yaml        - Non-sensitive defaults
#   hosts/*.yaml     - Physical machine config
#   nodes/*.yaml     - PVE instance config
#   envs/*.yaml      - Deployment config

.PHONY: help setup decrypt encrypt clean check validate host-config node-config

help:
	@echo "site-config - Site-specific configuration management"
	@echo ""
	@echo "Setup:"
	@echo "  make setup       - Configure git hooks and check dependencies"
	@echo ""
	@echo "Config Generation (run on target host):"
	@echo "  make host-config - Generate hosts/{hostname}.yaml from system info"
	@echo "  make node-config - Generate nodes/{hostname}.yaml from PVE info"
	@echo ""
	@echo "Secrets Management:"
	@echo "  make decrypt     - Decrypt secrets.yaml.enc to secrets.yaml"
	@echo "  make encrypt     - Encrypt secrets.yaml to secrets.yaml.enc"
	@echo "  make clean       - Remove plaintext secrets.yaml (keeps .enc)"
	@echo "  make check       - Verify encryption setup"
	@echo ""
	@echo "Validation:"
	@echo "  make validate    - Validate YAML syntax (optional)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - age:  apt install age"
	@echo "  - sops: https://github.com/getsops/sops/releases"
	@echo ""
	@echo "Age key location: ~/.config/sops/age/keys.txt"

setup:
	@echo "Configuring git hooks..."
	@git config core.hooksPath .githooks
	@echo "Checking dependencies..."
	@which age >/dev/null 2>&1 || (echo "ERROR: age not installed. Run: apt install age" && exit 1)
	@which sops >/dev/null 2>&1 || (echo "ERROR: sops not installed. See: https://github.com/getsops/sops/releases" && exit 1)
	@echo "Checking for age key..."
	@if [ -f ~/.config/sops/age/keys.txt ]; then \
		echo "Age key found."; \
		echo ""; \
		echo "IMPORTANT: Update .sops.yaml with your public key:"; \
		grep "public key:" ~/.config/sops/age/keys.txt; \
	else \
		echo ""; \
		echo "No age key found. To generate a new key:"; \
		echo "  mkdir -p ~/.config/sops/age"; \
		echo "  age-keygen -o ~/.config/sops/age/keys.txt"; \
		echo "  chmod 600 ~/.config/sops/age/keys.txt"; \
		echo ""; \
		echo "Then update .sops.yaml with your public key."; \
		echo ""; \
	fi
	@echo ""
	@echo "Setup complete."

decrypt:
	@if [ ! -f ~/.config/sops/age/keys.txt ]; then \
		echo "ERROR: No age key found at ~/.config/sops/age/keys.txt"; \
		echo "Run 'make setup' for instructions."; \
		exit 1; \
	fi
	@if [ -f secrets.yaml.enc ]; then \
		echo "Decrypting: secrets.yaml.enc -> secrets.yaml"; \
		sops --input-type yaml --output-type yaml -d secrets.yaml.enc > secrets.yaml || (rm -f secrets.yaml && exit 1); \
		echo "Done."; \
	else \
		echo "No secrets.yaml.enc found. Nothing to decrypt."; \
	fi

encrypt:
	@if [ ! -f secrets.yaml ]; then \
		echo "ERROR: No secrets.yaml found. Create it first."; \
		exit 1; \
	fi
	@echo "Encrypting: secrets.yaml -> secrets.yaml.enc"
	@sops --input-type yaml --output-type yaml -e secrets.yaml > secrets.yaml.enc
	@echo "Done."
	@echo ""
	@echo "To commit encrypted secrets to a private fork:"
	@echo "  1. Remove secrets.yaml.enc from .gitignore"
	@echo "  2. git add secrets.yaml.enc"
	@echo "  3. git commit"

clean:
	@echo "Removing plaintext secrets..."
	@rm -f secrets.yaml
	@echo "Done. Only secrets.yaml.enc remains."

check:
	@echo "Checking setup..."
	@echo ""
	@echo "Dependencies:"
	@printf "  age:  " && (which age >/dev/null 2>&1 && age --version || echo "NOT INSTALLED")
	@printf "  sops: " && (which sops >/dev/null 2>&1 && sops --version 2>&1 | head -1 || echo "NOT INSTALLED")
	@echo ""
	@echo "Git hooks:"
	@printf "  core.hooksPath: " && (git config core.hooksPath || echo "NOT SET")
	@echo ""
	@echo "Age key:"
	@if [ -f ~/.config/sops/age/keys.txt ]; then \
		echo "  Found: ~/.config/sops/age/keys.txt"; \
		grep "public key:" ~/.config/sops/age/keys.txt || true; \
	else \
		echo "  NOT FOUND"; \
	fi
	@echo ""
	@echo "Secrets file:"
	@if [ -f secrets.yaml.enc ]; then echo "  secrets.yaml.enc: EXISTS"; else echo "  secrets.yaml.enc: NOT FOUND"; fi
	@if [ -f secrets.yaml ]; then echo "  secrets.yaml: EXISTS (plaintext)"; else echo "  secrets.yaml: NOT FOUND"; fi
	@echo ""
	@echo "Config files:"
	@printf "  site.yaml:   " && ([ -f site.yaml ] && echo "EXISTS" || echo "NOT FOUND")
	@printf "  hosts/:      " && (ls -1 hosts/*.yaml 2>/dev/null | wc -l | xargs printf "%s files\n")
	@printf "  nodes/:      " && (ls -1 nodes/*.yaml 2>/dev/null | wc -l | xargs printf "%s files\n")
	@printf "  envs/:       " && (ls -1 envs/*.yaml 2>/dev/null | wc -l | xargs printf "%s files\n")

validate:
	@echo "Validating YAML syntax..."
	@for f in site.yaml hosts/*.yaml nodes/*.yaml envs/*.yaml; do \
		if [ -f "$$f" ]; then \
			python3 -c "import yaml; yaml.safe_load(open('$$f'))" 2>/dev/null && echo "  $$f: OK" || echo "  $$f: INVALID"; \
		fi; \
	done
	@if [ -f secrets.yaml ]; then \
		python3 -c "import yaml; yaml.safe_load(open('secrets.yaml'))" 2>/dev/null && echo "  secrets.yaml: OK" || echo "  secrets.yaml: INVALID"; \
	fi
	@echo "Done."

host-config:
	@HOSTNAME=$$(hostname -s); \
	OUTPUT="hosts/$$HOSTNAME.yaml"; \
	if [ -f "$$OUTPUT" ] && [ "$(FORCE)" != "1" ]; then \
		echo "ERROR: $$OUTPUT already exists. Use 'make host-config FORCE=1' to overwrite." >&2; \
		exit 1; \
	fi; \
	mkdir -p hosts && \
	FORCE=1 ./scripts/host-config.sh > "$$OUTPUT" && \
	echo "Generated: $$OUTPUT"

node-config:
	@HOSTNAME=$$(hostname -s); \
	OUTPUT="nodes/$$HOSTNAME.yaml"; \
	if [ -f "$$OUTPUT" ] && [ "$(FORCE)" != "1" ]; then \
		echo "ERROR: $$OUTPUT already exists. Use 'make node-config FORCE=1' to overwrite." >&2; \
		exit 1; \
	fi; \
	mkdir -p nodes && \
	FORCE=1 ./scripts/node-config.sh > "$$OUTPUT" && \
	echo "Generated: $$OUTPUT"
