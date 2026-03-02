#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

VERBOSE="${VERBOSE:-0}"

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed at: $(command -v brew)"
    return 0
  fi

  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add to PATH for current session
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  
  log "Homebrew installed successfully"
}

configure_shell() {
  local marker="homebrew"
  local bashrc="$HOME/.bashrc"
  
  backup_if_exists "$bashrc"
  
  local content
  content=$(cat <<'EOF'
# Initialize Homebrew
if [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
EOF
  )
  
  append_delimited "$bashrc" "$content" "$marker"
  log "Added Homebrew initialization to ~/.bashrc"
}

validate_installation() {
  # Check if brew is available
  if ! command -v brew &>/dev/null; then
    err "Homebrew not found in PATH"
    return 1
  fi
  
  # Test brew command
  if ! brew --version >/dev/null 2>&1; then
    err "Homebrew validation failed"
    return 1
  fi
  
  log "Homebrew validation passed"
}

main() {
  install_homebrew
  configure_shell
  validate_installation
  
  local version
  version=$(brew --version | head -n1 | awk '{print $2}')
  log "Installation successful: homebrew v${version}"
}

main "$@"
