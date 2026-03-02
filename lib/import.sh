#!/usr/bin/env bash
# Auto-import existing installations

# Detect if a component is already installed
detect_component() {
  local component="$1"
  
  case "$component" in
    git)
      # Check for git with our aliases
      if command -v git &>/dev/null && [[ -f "$HOME/.gitconfig" ]]; then
        if grep -q "dotfiles:git-aliases" "$HOME/.gitconfig" 2>/dev/null; then
          echo "true"
          return 0
        fi
      fi
      ;;
    shell)
      # Check for our shell customizations
      if [[ -f "$HOME/.bashrc" ]]; then
        if grep -q "dotfiles:shell" "$HOME/.bashrc" 2>/dev/null; then
          echo "true"
          return 0
        fi
      fi
      ;;
    vfox)
      # Check if vfox is in PATH
      if command -v vfox &>/dev/null; then
        echo "true"
        return 0
      fi
      ;;
    cli-tools)
      # Check for any of the CLI tools
      if command -v fzf &>/dev/null || command -v rg &>/dev/null || \
         command -v bat &>/dev/null || command -v exa &>/dev/null; then
        echo "true"
        return 0
      fi
      ;;
    kubernetes)
      # Check for kubectl
      if command -v kubectl &>/dev/null; then
        echo "true"
        return 0
      fi
      ;;
    cloud)
      # Check for AWS or Azure CLI or Google Cloud SDK
      if command -v aws &>/dev/null || command -v az &>/dev/null || command -v gcloud &>/dev/null; then
        echo "true"
        return 0
      fi
      ;;
  esac
  
  echo "false"
  return 0
}

# Get installed version of a component
get_installed_version() {
  local component="$1"
  local version="unknown"
  
  case "$component" in
    git)
      if command -v git &>/dev/null; then
        version=$(git --version 2>/dev/null | awk '{print $3}')
      fi
      ;;
    shell)
      if command -v bash &>/dev/null; then
        version=$(bash --version 2>/dev/null | head -n1 | awk '{print $4}')
      fi
      ;;
    vfox)
      if command -v vfox &>/dev/null; then
        version=$(vfox --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -n1)
      fi
      ;;
    cli-tools)
      # Use fzf version as representative
      if command -v fzf &>/dev/null; then
        version=$(fzf --version 2>/dev/null | awk '{print $1}')
      fi
      ;;
    kubernetes)
      if command -v kubectl &>/dev/null; then
        version=$(kubectl version --client --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -n1)
      fi
      ;;
    cloud)
      # Use AWS CLI version as representative
      if command -v aws &>/dev/null; then
        version=$(aws --version 2>/dev/null | awk '{print $1}' | cut -d'/' -f2)
      elif command -v az &>/dev/null; then
        version=$(az version 2>/dev/null | grep -oP '"azure-cli": "\K[^"]+' | head -n1)
      elif command -v gcloud &>/dev/null; then
        version=$(gcloud version 2>/dev/null | grep "Google Cloud SDK" | awk '{print $4}')
      fi
      ;;
  esac
  
  echo "${version:-unknown}"
}

# Import all detected installations to JSON
import_to_json() {
  log "Detecting existing installations..."
  
  local imported_count=0
  
  # Check all known components
  for component in git shell vfox cloud; do
    local is_installed
    is_installed=$(detect_component "$component")
    
    if [[ "$is_installed" == "true" ]]; then
      local version
      version=$(get_installed_version "$component")
      
      debug "Detected: $component v$version"
      track_component "$component" "$version" "imported" ""
      
      log "Imported: $component v$version"
      ((imported_count++))
    fi
  done
  
  if [[ $imported_count -gt 0 ]]; then
    log "Imported $imported_count existing installation(s)"
    log "These will be managed by dotfiles going forward"
  else
    debug "No existing installations detected"
  fi
}

# Upgrade a component from 'imported' to 'ok' status
upgrade_imported_to_ok() {
  local component="$1"
  local version="$2"
  
  local current_status
  current_status=$(read_component_status "$component")
  
  if [[ "$current_status" == "imported" ]]; then
    log "Upgrading $component from imported to managed status"
    
    # Get current backup dir (if any)
    local backup_dir
    if [[ -f "$DOTFILES_INSTALLED" ]]; then
      backup_dir=$(jq -r --arg name "$component" '.[$name].backup_dir // ""' "$DOTFILES_INSTALLED")
    fi
    
    track_component "$component" "$version" "ok" "$backup_dir"
    debug "Status upgraded: $component -> ok"
  fi
}

# Check if import is needed (no JSON file exists)
needs_import() {
  [[ ! -f "$DOTFILES_INSTALLED" ]]
}

# Run import if needed
auto_import() {
  if needs_import; then
    debug "No installation tracking found, scanning for existing components..."
    import_to_json
  else
    debug "Installation tracking exists, skipping auto-import"
  fi
  
  return 0
}
