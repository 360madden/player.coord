# ---------------------------------------------------------------------------
# CI Makefile for PlayerCoord RIFT Addon
#
# Usage:
#   make lint      - Run luacheck linter
#   make format    - Run stylua formatter (auto-fix)
#   make check     - Run stylua in check mode (fails if unformatted)
#   make ci        - Run all checks (lint + format-check)
#   make install   - Install dev dependencies
# ---------------------------------------------------------------------------

.PHONY: lint format check ci install

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
