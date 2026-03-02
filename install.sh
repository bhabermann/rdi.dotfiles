#!/usr/bin/env bash
set -euo pipefail

# Main installer for WSL dotfiles
# Orchestrates installation of Docker and corporate CA utilities

VERBOSE=0

log()   { printf "✓ %s\n" "$*"; }
warn()  { printf "⚠ WARNING: %s\n" "$*" >&2; }
err()   { printf "✗ ERROR: %s\n" "$*" >&2; }
debug() { [[ "$VERBOSE" -eq 1 ]] && printf "  [DEBUG] %s\n" "$*" || true; }

usage() {
  cat <<'EOF'
Usage:
  install.sh [--verbose] [--help]

Options:
  --verbose  Show detailed debug information during installation
  --help     Show this help message

Description:
  Installs WSL dotfiles utilities:
  - Docker Engine with Windows wrapper commands
  - Corporate CA certificate management tool
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Build verbose flag for sub-scripts
VERBOSE_FLAG=""
[[ "$VERBOSE" -eq 1 ]] && VERBOSE_FLAG="--verbose"

log "Starting dotfiles installation..."
debug "Verbose mode enabled"

debug "Installing Docker WSL and Windows wrappers..."
./docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh $VERBOSE_FLAG

debug "Installing corporate CA management tool..."
./update-corporate-ca/install/install-update-corporate-ca.sh $VERBOSE_FLAG

log "Installation complete!"
log "Run 'update-corporate-ca --help' for certificate management options"