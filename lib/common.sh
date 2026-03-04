#!/usr/bin/env bash
# Common utility functions for dotfiles management

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_INSTALLED="$HOME/.dotfiles-installed"
DOTFILES_BACKUP="$HOME/.dotfiles-backup"
DOTFILES_LOGS="$HOME/.dotfiles-logs"

LOG_ENABLED="${LOG_ENABLED:-0}"
CURRENT_LOG_FILE=""
PROGRESS_TOTAL=0
PROGRESS_CURRENT=0
PROGRESS_SPINNER_PID=""

# Logging functions (consistent with existing codebase)
log()   { printf "✓ %s\n" "$*"; }
warn()  { printf "⚠ WARNING: %s\n" "$*" >&2; }
err()   { printf "✗ ERROR: %s\n" "$*" >&2; }
debug() { [[ "$VERBOSE" -eq 1 ]] && printf "  [DEBUG] %s\n" "$*" || true; }

# Detect WSL environment.
is_wsl_env() {
  [[ -n "${WSL_INTEROP:-}" ]] || [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]
}

# True when a component was intentionally skipped in non-WSL installs.
is_non_wsl_skip_marker() {
  local component="$1"
  local version

  version="$(read_component_version "$component")"
  [[ "$version" == "skip-non-wsl" ]]
}

is_interactive_tty() {
  [[ -t 1 && -t 2 ]]
}

progress_init() {
  local total="${1:-0}"
  PROGRESS_TOTAL="$total"
  PROGRESS_CURRENT=0
}

progress_step() {
  local message="$1"
  if [[ "$PROGRESS_TOTAL" -gt 0 ]]; then
    PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
    printf "[%d/%d] %s\n" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "$message"
  else
    printf "[*] %s\n" "$message"
  fi
}

start_progress_spinner() {
  local message="$1"

  if ! is_interactive_tty; then
    return 0
  fi

  if [[ "${VERBOSE:-0}" -eq 1 ]]; then
    return 0
  fi

  if [[ -n "$PROGRESS_SPINNER_PID" ]]; then
    return 0
  fi

  (
    local frames='-\|/'
    local i=0
    while true; do
      printf "\r[%d/%d] %s %s" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "$message" "${frames:i%4:1}" >&2
      i=$((i + 1))
      sleep 0.1
    done
  ) &
  PROGRESS_SPINNER_PID=$!
}

stop_progress_spinner() {
  if [[ -z "$PROGRESS_SPINNER_PID" ]]; then
    return 0
  fi

  kill "$PROGRESS_SPINNER_PID" >/dev/null 2>&1 || true
  wait "$PROGRESS_SPINNER_PID" >/dev/null 2>&1 || true
  PROGRESS_SPINNER_PID=""
  printf "\r\033[K" >&2
}

progress_run() {
  local message="$1"
  shift

  start_progress_spinner "$message"
  if "$@"; then
    stop_progress_spinner
    return 0
  fi
  stop_progress_spinner
  return 1
}

# Setup logging for a component
setup_logging() {
  local component="$1"
  
  if [[ "$LOG_ENABLED" -eq 1 ]]; then
    mkdir -p "$DOTFILES_LOGS"
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    CURRENT_LOG_FILE="$DOTFILES_LOGS/${component}-${timestamp}.log"
    
    debug "Logging enabled: $CURRENT_LOG_FILE"
    exec > >(tee -a "$CURRENT_LOG_FILE")
    exec 2>&1
  fi
}

# Backup a file if it exists
backup_if_exists() {
  local filepath="$1"
  
  if [[ ! -f "$filepath" ]]; then
    debug "No existing file to backup: $filepath"
    return 0
  fi
  
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup_dir="$DOTFILES_BACKUP/$timestamp"
  
  # Preserve directory structure
  local relative_path="${filepath#$HOME/}"
  local backup_path="$backup_dir/$relative_path"
  local backup_parent
  backup_parent="$(dirname "$backup_path")"
  
  mkdir -p "$backup_parent"
  cp -a "$filepath" "$backup_path"
  
  debug "Backed up: $filepath -> $backup_path"
  echo "$timestamp"
}

# Restore a backup
restore_backup() {
  local filepath="$1"
  local timestamp="$2"
  
  local relative_path="${filepath#$HOME/}"
  local backup_path="$DOTFILES_BACKUP/$timestamp/$relative_path"
  
  if [[ ! -f "$backup_path" ]]; then
    warn "Backup not found: $backup_path"
    return 1
  fi
  
  cp -a "$backup_path" "$filepath"
  log "Restored: $filepath from backup $timestamp"
}

# Cleanup old backups, keeping only the last N
cleanup_old_backups() {
  local component="$1"
  local keep="${2:-10}"
  
  if [[ ! -d "$DOTFILES_BACKUP" ]]; then
    return 0
  fi
  
  # Get all backup directories sorted by timestamp (oldest first)
  local backup_dirs
  backup_dirs=$(find "$DOTFILES_BACKUP" -maxdepth 1 -type d -name "????????-??????" | sort)
  
  local total
  total=$(echo "$backup_dirs" | grep -c '^' || echo "0")
  
  if [[ $total -le $keep ]]; then
    debug "Total backups ($total) within retention limit ($keep)"
    return 0
  fi
  
  local to_remove=$((total - keep))
  echo "$backup_dirs" | head -n "$to_remove" | while read -r dir; do
    debug "Removing old backup: $dir"
    rm -rf "$dir"
  done
  
  log "Cleaned up $to_remove old backup(s), kept last $keep"
}

# Validate a command execution
validate_command() {
  local cmd="$1"
  local expected_pattern="${2:-}"
  
  debug "Validating: $cmd"
  
  local output
  if ! output=$(eval "$cmd" 2>&1); then
    debug "Command failed: $cmd"
    echo "failed"
    return 1
  fi
  
  if [[ -n "$expected_pattern" ]]; then
    if ! echo "$output" | grep -qE "$expected_pattern"; then
      debug "Output doesn't match pattern: $expected_pattern"
      echo "failed"
      return 1
    fi
  fi
  
  debug "Validation successful"
  echo "ok"
  return 0
}

# Track a component installation in JSON
track_component() {
  local name="$1"
  local version="$2"
  local status="$3"
  local backup_dir="${4:-}"
  
  local installed_at
  installed_at="$(date -Iseconds)"
  
  # Initialize JSON file if it doesn't exist
  if [[ ! -f "$DOTFILES_INSTALLED" ]]; then
    echo "{}" > "$DOTFILES_INSTALLED"
  fi
  
  # Update JSON using jq
  local temp_file
  temp_file="$(mktemp)"
  
  jq --arg name "$name" \
     --arg version "$version" \
     --arg status "$status" \
     --arg installed_at "$installed_at" \
     --arg backup_dir "$backup_dir" \
     '.[$name] = {
       "installed_at": $installed_at,
       "version": $version,
       "status": $status,
       "backup_dir": $backup_dir
     }' "$DOTFILES_INSTALLED" > "$temp_file"
  
  mv "$temp_file" "$DOTFILES_INSTALLED"
  debug "Tracked component: $name v$version ($status)"
}

# Read component status from JSON
read_component_status() {
  local name="$1"
  
  if [[ ! -f "$DOTFILES_INSTALLED" ]]; then
    echo "null"
    return
  fi
  
  jq -r --arg name "$name" '.[$name].status // "null"' "$DOTFILES_INSTALLED"
}

# Read component version from JSON
read_component_version() {
  local name="$1"

  if [[ ! -f "$DOTFILES_INSTALLED" ]]; then
    echo ""
    return
  fi

  jq -r --arg name "$name" '.[$name].version // ""' "$DOTFILES_INSTALLED"
}

# Check if component is already installed
is_installed() {
  local name="$1"
  local status
  status=$(read_component_status "$name")
  [[ "$status" == "ok" || "$status" == "imported" ]]
}

# Append content to a file with delimiters (or replace if exists)
append_delimited() {
  local filepath="$1"
  local content="$2"
  local marker="$3"
  
  local start_marker="# >>> dotfiles:$marker >>>"
  local end_marker="# <<< dotfiles:$marker <<<"
  
  # Create file if it doesn't exist
  if [[ ! -f "$filepath" ]]; then
    touch "$filepath"
  fi
  
  # Check if section already exists
  if grep -q "^$start_marker" "$filepath"; then
    debug "Section '$marker' exists, replacing content"
    
    # Use sed to replace content between markers
    local temp_file
    temp_file="$(mktemp)"
    
    awk -v start="$start_marker" \
        -v end="$end_marker" \
        -v content="$content" '
      BEGIN { in_section=0 }
      $0 == start { 
        print $0
        print content
        in_section=1
        next
      }
      $0 == end {
        print $0
        in_section=0
        next
      }
      !in_section { print }
    ' "$filepath" > "$temp_file"
    
    mv "$temp_file" "$filepath"
  else
    debug "Section '$marker' not found, appending"
    
    # Append new section
    {
      echo ""
      echo "$start_marker"
      echo "$content"
      echo "$end_marker"
    } >> "$filepath"
  fi
  
  log "Updated section '$marker' in $filepath"
}

# Remove delimited section from a file
remove_delimited() {
  local filepath="$1"
  local marker="$2"
  
  if [[ ! -f "$filepath" ]]; then
    return 0
  fi
  
  local start_marker="# >>> dotfiles:$marker >>>"
  local end_marker="# <<< dotfiles:$marker <<<"
  
  if ! grep -q "^$start_marker" "$filepath"; then
    debug "Section '$marker' not found in $filepath"
    return 0
  fi
  
  local temp_file
  temp_file="$(mktemp)"
  
  awk -v start="$start_marker" \
      -v end="$end_marker" '
    BEGIN { in_section=0; skip_blank=0 }
    $0 == start { 
      in_section=1
      skip_blank=1
      next
    }
    $0 == end {
      in_section=0
      next
    }
    !in_section {
      if (skip_blank && $0 == "") {
        skip_blank=0
        next
      }
      print
    }
  ' "$filepath" > "$temp_file"
  
  mv "$temp_file" "$filepath"
  log "Removed section '$marker' from $filepath"
}

# Parse YAML file for tool versions
parse_yaml() {
  local yaml_file="$1"
  local tool="$2"
  
  if [[ ! -f "$yaml_file" ]]; then
    err "YAML file not found: $yaml_file"
    return 1
  fi
  
  # Simple YAML parsing for our specific format
  # Format: tools:\n  toolname:\n    version: "x.y.z"
  local version
  version=$(awk -v tool="$tool" '
    $1 == tool":" { found=1; next }
    found && /version:/ { 
      gsub(/^[[:space:]]*version:[[:space:]]*"?/, "")
      gsub(/"?[[:space:]]*$/, "")
      print
      exit
    }
    found && /^[[:space:]]*[a-z]/ && !/version:/ { exit }
  ' "$yaml_file")
  
  echo "$version"
}

# Ensure required commands are available
require_cmd() {
  local cmd="$1"
  local package="${2:-$cmd}"
  
  if ! command -v "$cmd" &>/dev/null; then
    warn "Required command not found: $cmd"
    debug "Installing package: $package"
    
    sudo apt-get update -qq
    sudo apt-get install -y -qq "$package" >/dev/null 2>&1
    
    if ! command -v "$cmd" &>/dev/null; then
      err "Failed to install required command: $cmd"
      return 1
    fi
  fi
  
  debug "Command available: $cmd"
  return 0
}

# Ensure jq is installed (required for JSON operations)
ensure_jq() {
  require_cmd jq jq
}

# Load Homebrew environment into current shell process.
sync_homebrew_path() {
  local brew_bin="/home/linuxbrew/.linuxbrew/bin/brew"

  if [[ ! -x "$brew_bin" ]]; then
    debug "Homebrew binary not found at $brew_bin (skipping PATH sync)"
    return 0
  fi

  # shellcheck disable=SC1091
  eval "$("$brew_bin" shellenv)"
  debug "Homebrew PATH loaded for current process"
}

# Refresh trusted corporate CA certificates before network-heavy installs.
refresh_corporate_ca_before_vfox() {
  local ca_cmd="update-corporate-ca"
  local ca_args=()

  if ! command -v "$ca_cmd" &>/dev/null; then
    err "Required command not found before vfox install: $ca_cmd"
    err "Install or fix ca-updater first, then rerun."
    return 1
  fi

  [[ "${VERBOSE:-0}" -eq 1 ]] && ca_args+=("--verbose")

  log "Refreshing corporate CA certificates before vfox..."
  if ! sudo "$ca_cmd" "${ca_args[@]}"; then
    err "Corporate CA refresh failed; cannot continue with vfox installation."
    return 1
  fi

  log "Corporate CA refresh completed."
}
