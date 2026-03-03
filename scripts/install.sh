#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source library functions
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/dependencies.sh"
source "$REPO_ROOT/lib/rollback.sh"
source "$REPO_ROOT/lib/import.sh"

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


# Step 0: Install all required Ubuntu dependencies first
log "Installing required Ubuntu dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq jq curl ca-certificates git bash sudo build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev >/dev/null 2>&1
log "All Ubuntu dependencies installed."

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
  if "$REPO_ROOT/docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh" >/dev/null 2>&1; then
    track_component "docker" "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')" "ok"
    commit_transaction "docker"
  else
    rollback_transaction "docker"
    err "Installation failed: docker"
    exit 1
  fi
else
  log "Already installed: docker"
fi

# Install Corporate CA updater
if ! is_installed "ca-updater"; then
  begin_transaction "ca-updater"
  if "$REPO_ROOT/update-corporate-ca/install/install-update-corporate-ca.sh" >/dev/null 2>&1; then
    track_component "ca-updater" "1.0.0" "ok"
    commit_transaction "ca-updater"
  else
    rollback_transaction "ca-updater"
    err "Installation failed: ca-updater"
    exit 1
  fi
else
  log "Already installed: ca-updater"
fi

# Install essential components in dependency order
COMPONENTS=("git" "shell" "homebrew" "vfox")

# Resolve dependencies
ORDERED_COMPONENTS=($(resolve_dependencies "${COMPONENTS[@]}"))

for component in "${ORDERED_COMPONENTS[@]}"; do
  if is_installed "$component"; then
    log "Already installed: $component"
    # Run installer anyway to ensure configuration is up to date
    # Handle special case where component name differs from directory name
    component_dir="$component"
    [[ "$component" == "vfox" ]] && component_dir="dev-tools"
    
    installer="$REPO_ROOT/$component_dir/install/install-*.sh"
    # shellcheck disable=SC2086
    installer_path=$(ls $installer 2>/dev/null | head -n1)
    if [[ -f "$installer_path" ]]; then
      "$installer_path" >/dev/null 2>&1 || true
    fi
    continue
  fi
  
  log "Installing: $component"
  begin_transaction "$component"
  
  # Handle special case where component name differs from directory name
  component_dir="$component"
  [[ "$component" == "vfox" ]] && component_dir="dev-tools"
  
  installer="$REPO_ROOT/$component_dir/install/install-*.sh"
  # shellcheck disable=SC2086
  installer_path=$(ls $installer 2>/dev/null | head -n1)
  
  if [[ ! -f "$installer_path" ]]; then
    err "Installer not found: $installer_path"
    rollback_transaction "$component"
    rollback_cascade "$component"
    exit 1
  fi
  
  if "$installer_path"; then
    commit_transaction "$component"
  else
    err "Installation failed: $component"
    rollback_transaction "$component"
    rollback_cascade "$component"
    exit 1
  fi
done

log "✓ All essential components installed successfully!"
log ""
log "Sourcing ~/.bashrc to apply changes..."
# shellcheck disable=SC1090
source "$HOME/.bashrc" 2>/dev/null || true

# Show installed runtime versions
if command -v vfox &>/dev/null; then
  log "Installed runtime versions:"
  vfox current 2>/dev/null || true
fi

log ""
log "Next steps:"
log "  - Run './verify.sh' to validate all installations"
log "  - Run './update.sh' to update components"