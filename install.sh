#!/usr/bin/env bash
set -euo pipefail

# Main installer for WSL dotfiles
# Orchestrates installation of Docker, corporate CA, and optional dev tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/dependencies.sh
source "$SCRIPT_DIR/lib/dependencies.sh"
# shellcheck source=lib/rollback.sh
source "$SCRIPT_DIR/lib/rollback.sh"
# shellcheck source=lib/import.sh
source "$SCRIPT_DIR/lib/import.sh"

VERBOSE=0
INTERACTIVE=1
ESSENTIALS_ONLY=0
LOG_ENABLED=0

usage() {
  cat <<'EOF'
Usage:
  install.sh [options]

Options:
  --verbose         Show detailed debug information during installation
  --essentials-only Install only essential components (skip optional prompts)
  --all             Install all components without prompting
  --log             Enable logging to ~/.dotfiles-logs/
  --help            Show this help message

Description:
  Installs WSL dotfiles utilities with modular components.
  
  By default, runs in INTERACTIVE mode, prompting for optional components.
  
  Essential (always installed):
  - Docker Engine with Windows wrapper commands
  - Corporate CA certificate management tool
  - Git configuration and aliases
  - Basic shell environment
  
  Optional (with --interactive or --all):
  - vfox: Version manager for Node.js, Python, Java
  - cloud: Cloud CLIs (AWS, Azure, Google Cloud with AI support)

Examples:
  ./install.sh                     # Interactive mode (default)
  ./install.sh --essentials-only   # Install only essentials
  ./install.sh --all               # Install everything automatically
  ./install.sh --verbose --log     # Detailed output with logging
EOF
}

# Prompt user for component installation
prompt_install() {
  local component="$1"
  local description="$2"
  
  if [[ "$ESSENTIALS_ONLY" -eq 1 ]]; then
    return 1  # Skip optionals
  fi
  
  if [[ "$INTERACTIVE" -eq 0 ]]; then
    return 0  # Install everything (--all flag)
  fi
  
  printf "\n📦 %s\n   %s\n" "$component" "$description"
  read -p "   Install? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    --interactive|-i)
      INTERACTIVE=1
      ESSENTIALS_ONLY=0
      shift
      ;;
    --essentials-only)
      INTERACTIVE=0
      ESSENTIALS_ONLY=1
      shift
      ;;
    --all)
      INTERACTIVE=0
      ESSENTIALS_ONLY=0
      shift
      ;;
    --log)
      LOG_ENABLED=1
      export LOG_ENABLED
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

# Ensure jq is installed for JSON operations
ensure_jq

# Build verbose flag for sub-scripts
VERBOSE_FLAG=""
[[ "$VERBOSE" -eq 1 ]] && VERBOSE_FLAG="--verbose"

log "Starting dotfiles installation..."
debug "Verbose mode enabled"

# Auto-import existing installations if needed
auto_import

debug "Checking dependency graph for cycles..."
# Detect cycles in dependency graph
if ! detect_cycles; then
  err "Dependency cycle detected in component graph"
  exit 1
fi
debug "Dependency graph validated"

# Install essential components
log "Installing essential components..."

debug "Installing Docker WSL and Windows wrappers..."
"$SCRIPT_DIR/docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh" $VERBOSE_FLAG

debug "Installing corporate CA management tool..."
"$SCRIPT_DIR/update-corporate-ca/install/install-update-corporate-ca.sh" $VERBOSE_FLAG

# Install git and shell (new essentials)
debug "Installing Git configuration..."
begin_transaction "git"
if "$SCRIPT_DIR/git/install/install-git-config.sh" $VERBOSE_FLAG; then
  commit_transaction "git" "$(git --version 2>/dev/null | awk '{print $3}')"
else
  rollback_cascade "git"
  exit 1
fi

debug "Installing shell environment..."
begin_transaction "shell"
if "$SCRIPT_DIR/shell/install/install-shell-basics.sh" $VERBOSE_FLAG; then
  commit_transaction "shell" "$(bash --version | head -n1 | awk '{print $4}')"
else
  rollback_cascade "shell"
  exit 1
fi

# Collect optional components to install
OPTIONAL_COMPONENTS=()

if [[ "$ESSENTIALS_ONLY" -eq 0 ]]; then
  log "\nOptional components:"
  
  # Get all optional components
  OPTIONALS=($(get_optional_components))
  
  for component in "${OPTIONALS[@]}"; do
    desc=$(get_component_description "$component")
    
    if prompt_install "$component" "$desc"; then
      OPTIONAL_COMPONENTS+=("$component")
    fi
  done
fi

# Resolve dependencies and install in correct order
if [[ ${#OPTIONAL_COMPONENTS[@]} -gt 0 ]]; then
  log "\nResolving dependencies and determining installation order..."
  
  INSTALL_ORDER=($(resolve_dependencies "${OPTIONAL_COMPONENTS[@]}"))
  
  debug "Installation order: ${INSTALL_ORDER[*]}"
  
  for component in "${INSTALL_ORDER[@]}"; do
    local status
    status=$(read_component_status "$component")
    
    # Check if component is already imported, upgrade it
    if [[ "$status" == "imported" ]]; then
      log "Component '$component' already installed, upgrading to managed status..."
    fi
    
    log "\nInstalling: $component"
    
    begin_transaction "$component"
    
    if "$SCRIPT_DIR/$component/install/install-$component.sh" $VERBOSE_FLAG; then
      local version
      version=$(get_installed_version "$component")
      
      if [[ "$status" == "imported" ]]; then
        upgrade_imported_to_ok "$component" "$version"
      fi
      
      commit_transaction "$component" "$version"
    else
      rollback_cascade "$component"
      exit 1
    fi
  done
fi

# Cleanup old backups
cleanup_old_backups "all" 10

log "\n✨ Installation complete!"
log "Run 'update-corporate-ca --help' for certificate management options"
log "Run './verify.sh' to validate all installations"

if [[ "$ESSENTIALS_ONLY" -eq 0 ]]; then
  log "\nInstalled components are tracked in: ~/.dotfiles-installed"
  log "Use './update.sh' to update components"
  log "Use './uninstall.sh' to remove components"
fi