#!/usr/bin/env bash
set -euo pipefail

# Update installed dotfiles components

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
LOG_ENABLED=0

usage() {
  cat <<'EOF'
Usage:
  update.sh [options]

Options:
  --verbose  Show detailed debug information
  --log      Enable logging to ~/.dotfiles-logs/
  --help     Show this help message

Description:
  Updates all installed dotfiles components.
  
  - Re-runs installers for components with status 'ok'
  - Automatically upgrades 'imported' components to 'ok'
  - Skips components with status 'failed' (with warning)
  - Maintains dependency order (DAG)
  - Supports rollback on failure
EOF
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose) VERBOSE=1; shift ;;
      --log) LOG_ENABLED=1; export LOG_ENABLED; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown option: $1"; exit 1 ;;
    esac
  done

  log "Starting dotfiles update..."
  debug "Verbose mode enabled"
  
  # Ensure jq is installed
  ensure_jq
  
  # Check if tracking file exists
  if [[ ! -f "$DOTFILES_INSTALLED" ]]; then
    err "No installation tracking found: $DOTFILES_INSTALLED"
    log "Run './install.sh' to set up dotfiles first"
    exit 1
  fi
  
  # Get all installed components
  local all_components
  all_components=$(jq -r 'keys[]' "$DOTFILES_INSTALLED")
  
  if [[ -z "$all_components" ]]; then
    log "No components to update"
    exit 0
  fi
  
  # Filter components that can be updated (ok or imported)
  local updateable_components=()
  
  for component in $all_components; do
    local status
    status=$(read_component_status "$component")
    
    if [[ "$status" == "ok" ]] || [[ "$status" == "imported" ]]; then
      updateable_components+=("$component")
    elif [[ "$status" == "failed" ]]; then
      warn "Skipping $component: previous installation failed"
      warn "  Run './uninstall.sh $component' then reinstall to retry"
    fi
  done
  
  if [[ ${#updateable_components[@]} -eq 0 ]]; then
    log "No components available for update"
    exit 0
  fi
  
  # Resolve dependencies to get correct update order
  log "Resolving dependencies..."
  local update_order
  update_order=($(resolve_dependencies "${updateable_components[@]}"))
  
  debug "Update order: ${update_order[*]}"
  
  # Update each component
  for component in "${update_order[@]}"; do
    local status
    status=$(read_component_status "$component")
    
    log "\nUpdating: $component"
    
    # Check if it was imported, automatically upgrade it
    if [[ "$status" == "imported" ]]; then
      log "Component '$component' was imported, upgrading to managed status..."
    fi
    
    # Begin transaction
    begin_transaction "$component"
    
    # Run the installer
    local installer="$SCRIPT_DIR/$component/install/install-$component.sh"
    
    if [[ ! -f "$installer" ]]; then
      warn "Installer not found: $installer"
      warn "Skipping $component"
      rollback_transaction "$component"
      continue
    fi
    
    local verbose_flag=""
    [[ "$VERBOSE" -eq 1 ]] && verbose_flag="--verbose"
    
    if "$installer" $verbose_flag; then
      local version
      version=$(get_installed_version "$component")
      
      # Upgrade imported to ok if needed
      if [[ "$status" == "imported" ]]; then
        upgrade_imported_to_ok "$component" "$version"
      fi
      
      commit_transaction "$component" "$version"
    else
      rollback_cascade "$component"
      err "Update failed for: $component"
      exit 1
    fi
  done
  
  # Cleanup old backups
  log "\nCleaning up old backups..."
  cleanup_old_backups "all" 10
  
  log "\n✨ Update complete!"
  log "Run './verify.sh' to validate all installations"
}

main "$@"
