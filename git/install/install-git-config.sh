#!/usr/bin/env bash
set -euo pipefail

COMPONENT="git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

VERBOSE=0
GITCONFIG_SRC="$SCRIPT_DIR/../.gitconfig"
GITCONFIG_DEST="$HOME/.gitconfig"

usage() {
  cat <<'EOF'
Usage:
  install-git-config.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs Git configuration with useful aliases.
  Preserves existing .gitconfig by appending in delimited section.
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
  debug "Installing Git configuration..."

  # Backup existing gitconfig if it exists
  if [[ -f "$GITCONFIG_DEST" ]]; then
    backup_if_exists "$GITCONFIG_DEST"
  fi

  # Read the gitconfig content
  local gitconfig_content
  gitconfig_content=$(cat "$GITCONFIG_SRC")

  # Append to .gitconfig with delimiters
  append_delimited "$GITCONFIG_DEST" "$gitconfig_content" "git-aliases"

  # Validate git configuration
  if ! git config --list &>/dev/null; then
    err "Git configuration validation failed"
    return 1
  fi

  log "Git configuration installed successfully"
  debug "You can now use: git co, git st, git br, git lg"
}

main "$@"
