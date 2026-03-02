#!/usr/bin/env bash
set -euo pipefail

COMPONENT="cli-tools"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

VERBOSE=0
VERSIONS_YAML="$SCRIPT_DIR/../config/versions.yaml"

usage() {
  cat <<'EOF'
Usage:
  install-modern-cli.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs modern CLI utilities:
  - fzf: Fuzzy finder
  - ripgrep: Fast grep alternative
  - bat: Cat with syntax highlighting
  - exa: Modern ls replacement
EOF
}

install_fzf() {
  local version="0.46.1"
  
  if command -v fzf &>/dev/null; then
    log "fzf already installed, skipping"
    return 0
  fi
  
  debug "Installing fzf v$version..."
  
  local temp_dir
  temp_dir=$(mktemp -d)
  
  cd "$temp_dir"
  wget -q "https://github.com/junegunn/fzf/releases/download/$version/fzf-$version-linux_amd64.tar.gz"
  tar -xzf "fzf-$version-linux_amd64.tar.gz"
  sudo install -m 0755 fzf /usr/local/bin/fzf
  cd - >/dev/null
  rm -rf "$temp_dir"
  
  log "Installed: fzf v$version"
  
  # Configure fzf key bindings
  local fzf_config='# fzf key bindings and fuzzy completion
if command -v fzf &>/dev/null; then
  # Ctrl+R: command history
  bind -x '"'"'"\C-r": "history | fzf --tac --no-sort | sed '"'"'"'"'"'"'"'"'s/^[[:space:]]*[0-9]*[[:space:]]*//'"'"'"'"'"'"'"'"' | read -r line && READLINE_LINE=\"$line\" && READLINE_POINT=${#READLINE_LINE}"'"'"'
fi'
  
  append_delimited "$HOME/.bashrc" "$fzf_config" "fzf"
}

install_ripgrep() {
  if command -v rg &>/dev/null; then
    log "ripgrep already installed, skipping"
    return 0
  fi
  
  debug "Installing ripgrep..."
  
  sudo apt-get update -qq
  sudo apt-get install -y -qq ripgrep >/dev/null 2>&1
  
  local version
  version=$(rg --version | head -n1 | awk '{print $2}')
  log "Installed: ripgrep v$version"
}

install_bat() {
  if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
    log "bat already installed, skipping"
    return 0
  fi
  
  debug "Installing bat..."
  
  sudo apt-get update -qq
  sudo apt-get install -y -qq bat >/dev/null 2>&1
  
  # On Ubuntu, bat is installed as batcat
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
  fi
  
  local version
  version=$(bat --version 2>/dev/null || batcat --version 2>/dev/null | head -n1 | awk '{print $2}')
  log "Installed: bat v$version"
}

install_exa() {
  if command -v exa &>/dev/null; then
    log "exa already installed, skipping"
    return 0
  fi
  
  debug "Installing exa..."
  
  # Try apt first
  if sudo apt-get install -y -qq exa >/dev/null 2>&1; then
    local version
    version=$(exa --version | head -n1 | awk '{print $2}')
    log "Installed: exa v$version"
  else
    warn "exa not available in apt, skipping"
  fi
}

configure_aliases() {
  debug "Configuring CLI tool aliases..."
  
  local cli_aliases='# Modern CLI tool aliases
if command -v bat &>/dev/null; then
  alias cat="bat --paging=never"
fi

if command -v exa &>/dev/null; then
  alias ls="exa"
  alias ll="exa -l"
  alias la="exa -la"
  alias tree="exa --tree"
fi

if command -v rg &>/dev/null; then
  alias grep="rg"
fi'
  
  # Append to .bash_aliases if it exists
  if [[ -f "$HOME/.bash_aliases" ]]; then
    append_delimited "$HOME/.bash_aliases" "$cli_aliases" "cli-tools"
  fi
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
  debug "Installing modern CLI tools..."

  # Ensure wget is available
  require_cmd wget wget

  install_fzf
  install_ripgrep
  install_bat
  install_exa
  configure_aliases

  log "CLI tools installation complete"
}

main "$@"
