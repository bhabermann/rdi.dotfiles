#!/usr/bin/env bash
set -euo pipefail

COMPONENT="shell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

VERBOSE=0
BASHRC_SRC="$SCRIPT_DIR/../.bashrc"
ALIASES_SRC="$SCRIPT_DIR/../.bash_aliases"
BASHRC_DEST="$HOME/.bashrc"
ALIASES_DEST="$HOME/.bash_aliases"

usage() {
  cat <<'EOF'
Usage:
  install-shell-basics.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs basic shell environment customizations:
  - Enhanced .bashrc with history settings
  - Common aliases in .bash_aliases
  
  Preserves existing configurations by appending in delimited sections.
EOF
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose) VERBOSE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown option: $1"; exit 1 ;;
    esac
  done

  debug "Verbose mode enabled"
  debug "Installing shell environment..."

  # Backup existing files
  if [[ -f "$BASHRC_DEST" ]]; then
    backup_if_exists "$BASHRC_DEST"
  fi
  
  if [[ -f "$ALIASES_DEST" ]]; then
    backup_if_exists "$ALIASES_DEST"
  fi

  # Read bashrc content
  local bashrc_content
  bashrc_content=$(cat "$BASHRC_SRC")

  # Append to .bashrc with delimiters
  append_delimited "$BASHRC_DEST" "$bashrc_content" "shell"

  # Install aliases file (copy directly, not append)
  cp "$ALIASES_SRC" "$ALIASES_DEST"
  log "Installed: $ALIASES_DEST"

  # Validate bash configuration
  if ! bash -n "$BASHRC_DEST" 2>/dev/null; then
    err "Bash configuration validation failed"
    return 1
  fi

  log "Shell environment installed successfully"
  debug "Source your .bashrc or restart your shell to apply changes"
}

main "$@"
