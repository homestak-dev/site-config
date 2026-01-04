# site-config Makefile
# Secrets management for homestak deployments

.PHONY: help setup decrypt encrypt clean check

help:
	@echo "site-config - Site-specific configuration management"
	@echo ""
	@echo "Setup:"
	@echo "  make setup    - Configure git hooks and check dependencies"
	@echo ""
	@echo "Secrets Management:"
	@echo "  make decrypt  - Decrypt all .enc files to plaintext"
	@echo "  make encrypt  - Encrypt all plaintext files to .enc"
	@echo "  make clean    - Remove plaintext files (keeps .enc)"
	@echo "  make check    - Verify encryption setup"
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
	@for encfile in $$(find hosts envs -name "*.enc" -type f 2>/dev/null); do \
		plainfile="$${encfile%.enc}"; \
		echo "Decrypting: $$encfile -> $$plainfile"; \
		sops -d "$$encfile" > "$$plainfile" || (rm -f "$$plainfile" && exit 1); \
	done
	@echo "Done."

encrypt:
	@for plainfile in $$(find hosts envs -type f -name "*.tfvars" ! -name "*.enc" 2>/dev/null); do \
		encfile="$${plainfile}.enc"; \
		echo "Encrypting: $$plainfile -> $$encfile"; \
		sops -e "$$plainfile" > "$$encfile"; \
	done
	@echo "Done. Encrypted files are ready."
	@echo ""
	@echo "To commit encrypted secrets to a private fork:"
	@echo "  1. Remove *.enc patterns from .gitignore"
	@echo "  2. git add hosts/*.enc envs/*/*.enc"
	@echo "  3. git commit"

clean:
	@echo "Removing plaintext secrets..."
	@find hosts envs -type f -name "*.tfvars" ! -name "*.enc" -delete 2>/dev/null || true
	@echo "Done. Only .enc files remain."

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
	@echo "Encrypted files:"
	@find hosts envs -name "*.enc" -type f 2>/dev/null | wc -l | xargs printf "  %s .enc files\n"
	@echo ""
	@echo "Plaintext files:"
	@find hosts envs -type f -name "*.tfvars" ! -name "*.enc" 2>/dev/null | wc -l | xargs printf "  %s plaintext files\n"
