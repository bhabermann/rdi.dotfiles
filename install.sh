#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/dependencies.sh"
source "$SCRIPT_DIR/lib/rollback.sh"
source "$SCRIPT_DIR/lib/import.sh"

export VERBOSE=0

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose)
      VERBOSE=1
      export VERBOSE
      ;;
    --help|-h)
      cat <<'EOF'
Usage: ./install.sh [--verbose]

Installs essential dotfiles components:
  - Docker Engine (with Windows wrappers)
  - Corporate CA certificate updater
  - Git configuration
  - Shell basics (bash)
  - Homebrew package manager
  - vfox version manager

Options:
  --verbose    Show detailed installation output
  --help       Show this help message
EOF
      exit 0
      ;;
    *)
      err "Unknown option: $arg"
      exit 1
      ;;
  esac
done

log "Starting dotfiles installation..."

# Ensure jq is available for JSON tracking
ensure_jq

# Auto-import existing installations
auto_import

# Detect dependency cycles
detect_cycles || { err "Dependency cycle detected!"; exit 1; }

log "Installing essential components..."

# Install Docker
if ! is_installed "docker"; then
  begin_transaction "docker"
  if "$SCRIPT_DIR/docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh" >/dev/null 2>&1; then
    track_component "docker" "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')" "ok"
    commit_transaction "docker"
  else
    rollback_transaction "docker"
    err "Installation failed: docker"
    exit 1
  fi
fi

# Install Corporate CA updater
if ! is_installed "ca-updater"; then
  begin_transaction "ca-updater"
  if "$SCRIPT_DIR/update-corporate-ca/install/install-update-corporate-ca.sh" >/dev/null 2>&1; then
    track_component "ca-updater" "1.0.0" "ok"
    commit_transaction "ca-updater"
  else
    rollback_transaction "ca-updater"
    err "Installation failed: ca-updater"
    exit 1
  fi
fi

# Install essential components in dependency order
COMPONENTS=("git" "shell" "homebrew" "vfox")

# Resolve dependencies
ORDERED_COMPONENTS=($(resolve_dependencies "${COMPONENTS[@]}"))

for component in "${ORDERED_COMPONENTS[@]}"; do
  if is_installed "$component"; then
    log "Already installed: $component"
    continue
  fi
  
  log "Installing: $component"
  begin_transaction "$component"
  
  local installer="$SCRIPT_DIR/$component/install/install-${component}*.sh"
  # shellcheck disable=SC2086
  installer_path=$(ls $installer 2>/dev/null | head -n1)
  
  if [[ ! -f "$installer_path" ]]; then
    err "Installer not found: $installer_path"
    rollback_transaction "$component"
    rollback_cascade
    exit 1
  fi
  
  if "$installer_path"; then
    commit_transaction "$component"
  else
    err "Installation failed: $component"
    rollback_transaction "$component"
    rollback_cascade
    exit 1
  fi
done

log "✓ All essential components installed successfully!"
log ""
log "Next steps:"
log "  - Run './verify.sh' to validate all installations"
log "  - Run './update.sh' to update components"
log "  - Restart your shell or run 'source ~/.bashrc' to load changes"