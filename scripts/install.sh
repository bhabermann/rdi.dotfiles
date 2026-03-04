#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source library functions
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/dependencies.sh"
source "$REPO_ROOT/lib/rollback.sh"
source "$REPO_ROOT/lib/import.sh"

export VERBOSE="${VERBOSE:-0}"
export LOG_ENABLED="${LOG_ENABLED:-0}"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose)
      VERBOSE=1
      export VERBOSE
      ;;
    --log)
      LOG_ENABLED=1
      export LOG_ENABLED
      ;;
    --help|-h)
      cat <<'EOF'
Usage: ./install.sh [--verbose] [--log]

Installs essential dotfiles components:
  - Docker Engine (with Windows wrappers)
  - Corporate CA certificate updater
  - Git configuration
  - Shell basics (bash)
  - Homebrew package manager
  - vfox version manager

Options:
  --verbose    Show detailed installation output
  --log        Enable log files in ~/.dotfiles-logs
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
progress_init 12
progress_step "Installing required Ubuntu dependencies"
log "Installing required Ubuntu dependencies..."
if [[ "$VERBOSE" -eq 1 ]]; then
  progress_run "Running apt-get update" sudo apt-get update
  progress_run "Installing apt dependencies" sudo apt-get install -y jq curl ca-certificates git bash sudo build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
else
  progress_run "Running apt-get update" sudo apt-get update -qq
  progress_run "Installing apt dependencies" sudo apt-get install -y -qq jq curl ca-certificates git bash sudo build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
fi
log "All Ubuntu dependencies installed."

log "Starting dotfiles installation..."
debug "Verbose mode enabled"
debug "File logging enabled: $LOG_ENABLED"

# Ensure jq is available for JSON tracking
progress_step "Validating jq dependency"
ensure_jq

# Auto-import existing installations
progress_step "Importing existing installations"
auto_import

# Detect dependency cycles
progress_step "Checking dependency graph for cycles"
detect_cycles || { err "Dependency cycle detected!"; exit 1; }

log "Installing essential components..."

# Install Docker
progress_step "Installing component: docker"
if ! is_installed "docker"; then
  if ! is_wsl_env; then
    warn "Skipping docker installation on non-WSL environment."
    track_component "docker" "skip-non-wsl" "ok" ""
  else
    begin_transaction "docker"
    docker_args=()
    [[ "$VERBOSE" -eq 1 ]] && docker_args+=("--verbose")
    if "$REPO_ROOT/docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh" "${docker_args[@]}"; then
      commit_transaction "docker" "$(get_installed_version "docker")"
    else
      rollback_transaction "docker"
      err "Installation failed: docker"
      exit 1
    fi
  fi
else
  log "Already installed: docker"
fi

# Install Corporate CA updater
progress_step "Installing component: ca-updater"
if ! is_installed "ca-updater"; then
  if ! is_wsl_env; then
    warn "Skipping ca-updater installation on non-WSL environment."
    track_component "ca-updater" "skip-non-wsl" "ok" ""
  else
    begin_transaction "ca-updater"
    ca_args=()
    [[ "$VERBOSE" -eq 1 ]] && ca_args+=("--verbose")
    if "$REPO_ROOT/update-corporate-ca/install/install-update-corporate-ca.sh" "${ca_args[@]}"; then
      commit_transaction "ca-updater" "$(get_installed_version "ca-updater")"
    else
      rollback_transaction "ca-updater"
      err "Installation failed: ca-updater"
      exit 1
    fi
  fi
else
  log "Already installed: ca-updater"
fi

# Install essential components in dependency order
COMPONENTS=("git" "shell" "homebrew" "cli-tools" "vfox")

# Resolve dependencies
ORDERED_COMPONENTS=($(resolve_dependencies "${COMPONENTS[@]}"))

for component in "${ORDERED_COMPONENTS[@]}"; do
  progress_step "Installing component: $component"
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
      if [[ "$component" == "vfox" ]]; then
        refresh_corporate_ca_before_vfox || exit 1
      fi
      component_args=()
      [[ "$VERBOSE" -eq 1 ]] && component_args+=("--verbose")
      "$installer_path" "${component_args[@]}" || true
      [[ "$component" == "homebrew" ]] && sync_homebrew_path
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
  
  if [[ "$component" == "vfox" ]]; then
    if ! refresh_corporate_ca_before_vfox; then
      rollback_cascade "$component"
      err "Installation failed: $component"
      exit 1
    fi
  fi

  component_args=()
  [[ "$VERBOSE" -eq 1 ]] && component_args+=("--verbose")
  if "$installer_path" "${component_args[@]}"; then
    [[ "$component" == "homebrew" ]] && sync_homebrew_path
    commit_transaction "$component" "$(get_installed_version "$component")"
  else
    err "Installation failed: $component"
    rollback_transaction "$component"
    rollback_cascade "$component"
    exit 1
  fi
done

progress_step "Finalizing installation"
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
