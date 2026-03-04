#!/usr/bin/env bash
# Transaction and rollback management for component installations

# Transaction stack (LIFO)
TRANSACTION_STACK=()
declare -A TRANSACTION_BACKUPS
declare -A TRANSACTION_COMPONENTS

# Begin a transaction for a component installation
begin_transaction() {
  local component="$1"
  
  debug "Beginning transaction for: $component"
  
  # Push to stack
  TRANSACTION_STACK+=("$component")
  TRANSACTION_COMPONENTS["$component"]=1
  
  # Create backup timestamp
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  TRANSACTION_BACKUPS["$component"]="$timestamp"
  
  # Setup logging if enabled
  if [[ "$LOG_ENABLED" -eq 1 ]]; then
    setup_logging "$component"
  fi
  
  debug "Transaction started: $component (backup: $timestamp)"
}

# Commit a successful transaction
commit_transaction() {
  local component="$1"
  local version="${2:-unknown}"
  local backup_dir="${TRANSACTION_BACKUPS[$component]:-}"
  
  debug "Committing transaction for: $component"
  
  # Validate component
  if ! validate_component "$component" >/dev/null; then
    warn "Validation failed for $component"
    rollback_transaction "$component"
    return 1
  fi
  
  # Track successful installation
  track_component "$component" "$version" "ok" "$backup_dir"
  
  # Remove from stack (only if it's the top)
  if [[ "${TRANSACTION_STACK[-1]}" == "$component" ]]; then
    unset 'TRANSACTION_STACK[-1]'
  fi
  
  unset "TRANSACTION_COMPONENTS[$component]"

  if [[ -n "$version" && "$version" != "unknown" ]]; then
    log "Installation successful: $component v$version"
  else
    log "Installation successful: $component"
  fi
  return 0
}

# Rollback a single transaction
rollback_transaction() {
  local component="$1"
  
  warn "Rolling back: $component"
  
  local backup_timestamp="${TRANSACTION_BACKUPS[$component]:-}"
  
  # Remove component entry from JSON
  if [[ -f "$DOTFILES_INSTALLED" ]]; then
    local temp_file
    temp_file="$(mktemp)"
    jq --arg name "$component" 'del(.[$name])' "$DOTFILES_INSTALLED" > "$temp_file"
    mv "$temp_file" "$DOTFILES_INSTALLED"
  fi
  
  # Restore backups if they exist
  if [[ -n "$backup_timestamp" ]] && [[ -d "$DOTFILES_BACKUP/$backup_timestamp" ]]; then
    debug "Restoring backups from: $backup_timestamp"
    
    # Restore all files from this backup
    find "$DOTFILES_BACKUP/$backup_timestamp" -type f | while read -r backup_file; do
      local relative_path="${backup_file#$DOTFILES_BACKUP/$backup_timestamp/}"
      local original_path="$HOME/$relative_path"
      
      cp -a "$backup_file" "$original_path"
      debug "Restored: $original_path"
    done
  fi
  
  # Clean up transaction tracking
  unset "TRANSACTION_BACKUPS[$component]"
  unset "TRANSACTION_COMPONENTS[$component]"
  
  log "Rollback complete: $component"
}

# Rollback all transactions in cascade (reverse order)
rollback_cascade() {
  local failed_component="$1"
  
  err "Installation failed: $failed_component"
  warn "Rolling back all dependent installations..."
  
  # Get the stack in reverse order
  local stack_size=${#TRANSACTION_STACK[@]}
  
  for ((i=stack_size-1; i>=0; i--)); do
    local component="${TRANSACTION_STACK[$i]}"
    
    if [[ "$component" == "$failed_component" ]]; then
      rollback_transaction "$component"
    else
      warn "Cascading rollback: $component (depends on $failed_component)"
      rollback_transaction "$component"
    fi
  done
  
  # Clear the stack
  TRANSACTION_STACK=()
  
  err "All installations rolled back due to failure in: $failed_component"
  return 1
}

# Validate a component installation
validate_component() {
  local component="$1"
  
  case "$component" in
    git)
      validate_command "git --version" "git version" >/dev/null
      ;;
    shell)
      validate_command "bash --version" "GNU bash" >/dev/null
      ;;
    vfox)
      validate_command "vfox --version" "vfox" >/dev/null
      ;;
    cli-tools)
      # Check at least one tool is installed
      if command -v fzf &>/dev/null || command -v rg &>/dev/null; then
        return 0
      else
        return 1
      fi
      ;;
    kubernetes)
      validate_command "kubectl version --client" "Client Version" >/dev/null
      ;;
    cloud)
      # Check at least one cloud CLI is installed
      if command -v aws &>/dev/null || command -v az &>/dev/null || command -v gcloud &>/dev/null; then
        return 0
      else
        return 1
      fi
      ;;
    *)
      debug "No validation defined for: $component"
      return 0
      ;;
  esac
}

# Check if we're currently in a transaction
in_transaction() {
  [[ ${#TRANSACTION_STACK[@]} -gt 0 ]]
}

# Get current transaction depth
transaction_depth() {
  echo "${#TRANSACTION_STACK[@]}"
}

# List components in current transaction
list_transaction_components() {
  echo "${TRANSACTION_STACK[@]}"
}
