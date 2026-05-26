# ---------------------------------------------------------------------------
# CI Makefile for player.coord RIFT Addon
#
# Usage:
#   make lint      - Run luacheck linter
#   make format    - Run stylua formatter (auto-fix)
#   make check     - Run stylua in check mode (fails if unformatted)
#   make ci        - Run all checks (lint + format-check)
#   make deploy    - Copy addons to the RIFT Interface/AddOns folder
#   make install   - Install dev dependencies
# ---------------------------------------------------------------------------

# RIFT addons folder (override with: make deploy RIFT_DIR=/path/to/RIFT)
RIFT_DIR ?= $(USERPROFILE)/Documents/RIFT
ADDONS_DEST = $(RIFT_DIR)/Interface/AddOns

.PHONY: lint format check ci deploy install

# Default target runs all CI checks
default: ci

# Install lua dev dependencies via LuaRocks
install:
	@echo "Installing Lua development tools..."
	@which luarocks > /dev/null 2>&1 || (echo "ERROR: luarocks not found. Install from https://luarocks.org/" && exit 1)
	luarocks install luacheck --local
	@echo "To install stylua: cargo install stylua (or download from https://github.com/JohnnyMorganz/StyLua/releases)"

# Lint check
lint:
	@echo "=== Running luacheck ==="
	luacheck . --config .luacheckrc
	@echo "=== Lint passed ==="

# Auto-format all Lua files
format:
	@echo "=== Running stylua (format) ==="
	stylua Interface/
	@echo "=== Format complete ==="

# Check if formatting is up to date (CI mode)
check:
	@echo "=== Running stylua (check mode) ==="
	stylua --check Interface/
	@echo "=== Format check passed ==="

# Full CI pipeline
ci: lint check
	@echo "=== All CI checks passed! ==="

# Deploy addon files to the RIFT addons folder
deploy:
	@echo "=== Deploying to $(ADDONS_DEST) ==="
	@mkdir -p "$(ADDONS_DEST)/player.coord"
	cp Interface/AddOns/player.coord/Main.lua "$(ADDONS_DEST)/player.coord/"
	cp Interface/AddOns/player.coord/RiftAddon.toc "$(ADDONS_DEST)/player.coord/"
	@echo "=== Deploy complete ==="
