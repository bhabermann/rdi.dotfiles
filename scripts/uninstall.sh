#!/usr/bin/env bash
set -euo pipefail

# Uninstall dotfiles components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source library functions
# shellcheck source=lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=lib/dependencies.sh
source "$REPO_ROOT/lib/dependencies.sh"

VERBOSE="${VERBOSE:-0}"
FORCE=0

usage() {
  cat <<'EOF'
Usage:
  uninstall.sh [options] [component...]

Options:
  --verbose  Show detailed debug information
  --force    Skip dependency checks (dangerous!)
  --help     Show this help message

Arguments:
  component  One or more components to uninstall (optional)
             If not specified, interactive selection will be shown

Description:
  Uninstalls dotfiles components:
  - Removes delimited sections from config files
  - Restores backups if available
  - Removes component from tracking JSON
  - Verifies no other components depend on it (unless --force)
  
Examples:
  ./uninstall.sh               # Interactive selection
  ./uninstall.sh vfox          # Uninstall vfox only
  ./uninstall.sh vfox homebrew # Uninstall multiple components
EOF
}

uninstall_component() {
  local component="$1"
  
  log "Uninstalling: $component"
  
  # Get backup directory
  local backup_dir
  if [[ -f "$DOTFILES_INSTALLED" ]]; then
    backup_dir=$(jq -r --arg name "$component" '.[$name].backup_dir // ""' "$DOTFILES_INSTALLED")
  fi
  
  # Remove delimited sections based on component
  case "$component" in
    git)
      remove_delimited "$HOME/.gitconfig" "git-aliases"
      ;;
    shell)
      remove_delimited "$HOME/.bashrc" "shell"
      if [[ -f "$HOME/.bash_aliases" ]]; then
        debug "Removing .bash_aliases"
        rm -f "$HOME/.bash_aliases"
      fi
      ;;
    vfox)
      remove_delimited "$HOME/.bashrc" "vfox"
      if [[ -f "$HOME/.zshrc" ]]; then
        remove_delimited "$HOME/.zshrc" "vfox"
      fi
      if [[ -d "$HOME/.vfox" ]]; then
        debug "Removing vfox directory"
        rm -rf "$HOME/.vfox"
      fi
      ;;
    homebrew)
      remove_delimited "$HOME/.bashrc" "homebrew"
      # Note: Homebrew itself remains in /home/linuxbrew/.linuxbrew
      # To fully remove, run: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
      ;;
  esac
  
  # Restore backup if available
  if [[ -n "$backup_dir" ]] && [[ -d "$DOTFILES_BACKUP/$backup_dir" ]]; then
    log "Backup available from: $backup_dir"
    read -p "Restore backup? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      find "$DOTFILES_BACKUP/$backup_dir" -type f | while read -r backup_file; do
        local relative_path="${backup_file#$DOTFILES_BACKUP/$backup_dir/}"
        local original_path="$HOME/$relative_path"
        restore_backup "$original_path" "$backup_dir"
      done
    fi
  fi
  
  # Remove from tracking JSON
  if [[ -f "$DOTFILES_INSTALLED" ]]; then
    local temp_file
    temp_file="$(mktemp)"
    jq --arg name "$component" 'del(.[$name])' "$DOTFILES_INSTALLED" > "$temp_file"
    mv "$temp_file" "$DOTFILES_INSTALLED"
  fi
  
  log "Uninstalled: $component"
}

interactive_select() {
  echo "Installed components:" >&2
  echo "" >&2
  local components
  components=$(jq -r 'keys[]' "$DOTFILES_INSTALLED")
  local -a component_list=()
  local index=1
  for component in $components; do
    local status version
    status=$(read_component_status "$component")
    version=$(jq -r --arg name "$component" '.[$name].version // "unknown"' "$DOTFILES_INSTALLED")
    printf "  %d) %s (v%s, status: %s)\n" "$index" "$component" "$version" "$status" >&2
    component_list+=("$component")
    ((index++))
  done
  echo "" >&2
  local selected=""
  while [[ -z "$selected" ]]; do
    local selection=""
    if [[ -t 0 ]]; then
      # Interactive terminal
      read -p "Select components to uninstall (e.g., 1 3 4 or 'all'): " -r selection
    else
      # Non-interactive (pipe or redirect)
      read -r selection || selection=""
    fi
    if [[ "$selection" == "all" ]]; then
      selected="${component_list[*]}"
      break
    fi
    local -a chosen=()
    for num in $selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#component_list[@]} ]]; then
        chosen+=("${component_list[$num-1]}")
      else
        warn "Invalid selection: $num"
      fi
    done
    if [[ ${#chosen[@]} -gt 0 ]]; then
      selected="${chosen[*]}"
    else
      warn "No valid components selected. Please try again."
    fi
  done
  # Only print component names to stdout, everything else to stderr
  echo "$selected"
}

main() {
  local components_to_uninstall=()
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose) VERBOSE=1; shift ;;
      --force) FORCE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *)
        # Assume it's a component name
        components_to_uninstall+=("$1")
        shift
        ;;
    esac
  done

  log "Starting dotfiles uninstall..."
  debug "Verbose mode enabled"
  
  # Ensure jq is installed
  ensure_jq
  
  # Check if tracking file exists
  if [[ ! -f "$DOTFILES_INSTALLED" ]]; then
    err "No installation tracking found: $DOTFILES_INSTALLED"
    log "Nothing to uninstall"
    exit 1
  fi
  
  # If no components specified, use interactive selection
  if [[ ${#components_to_uninstall[@]} -eq 0 ]]; then
    local selected
    selected=$(interactive_select)
    
    if [[ -z "$selected" ]]; then
      log "No components selected"
      exit 0
    fi
    
    read -a components_to_uninstall <<< "$selected"
  fi
  
  # Verify each component is installed
  for component in "${components_to_uninstall[@]}"; do
    local status
    status=$(read_component_status "$component")
    
    if [[ "$status" == "null" ]]; then
      err "Component not installed: $component"
      exit 1
    fi
  done
  
  # Check dependencies (unless --force)
  if [[ "$FORCE" -eq 0 ]]; then
    for component in "${components_to_uninstall[@]}"; do
      local dependents
      dependents=($(get_dependents "$component"))
      
      if [[ ${#dependents[@]} -gt 0 ]]; then
        # Check if all dependents are also being uninstalled
        local has_external_dependent=0
        
        for dependent in "${dependents[@]}"; do
          local being_uninstalled=0
          
          for uninstall_comp in "${components_to_uninstall[@]}"; do
            if [[ "$dependent" == "$uninstall_comp" ]]; then
              being_uninstalled=1
              break
            fi
          done
          
          if [[ $being_uninstalled -eq 0 ]]; then
            err "Cannot uninstall $component: required by $dependent"
            warn "Uninstall $dependent first, or use --force to bypass this check"
            has_external_dependent=1
          fi
        done
        
        if [[ $has_external_dependent -eq 1 ]]; then
          exit 1
        fi
      fi
    done
  fi
  
  # Confirm uninstallation
  echo ""
  warn "About to uninstall: ${components_to_uninstall[*]}"
  read -p "Continue? [y/N] " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Uninstall cancelled"
    exit 0
  fi
  
  # Uninstall in reverse dependency order
  local uninstall_order
  uninstall_order=($(resolve_dependencies "${components_to_uninstall[@]}"))
  
  # Reverse the order
  local reversed=()
  for ((i=${#uninstall_order[@]}-1; i>=0; i--)); do
    reversed+=("${uninstall_order[$i]}")
  done

  progress_init $((1 + ${#reversed[@]}))
  
  # Uninstall each component
  for component in "${reversed[@]}"; do
    progress_step "Uninstalling component: $component"
    uninstall_component "$component"
  done
  
  # Cleanup old backups
  progress_step "Cleaning up old backups"
  cleanup_old_backups "all" 10
  
  log "\n✨ Uninstall complete!"
  log "Restart your shell or run: source ~/.bashrc"
}

main "$@"
