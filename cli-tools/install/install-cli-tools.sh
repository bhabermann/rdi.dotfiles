#!/usr/bin/env bash
set -euo pipefail

COMPONENT="cli-tools"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../../lib/dependencies.sh
source "$ROOT_DIR/lib/dependencies.sh"

VERBOSE=0

usage() {
  cat <<'EOF'
Usage:
  install-cli-tools.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs essential CLI tools via Homebrew:
  - zoxide: smarter cd command with frecency
  - fzf: fuzzy finder
  - ripgrep: faster grep
  - bat: better cat with syntax highlighting
  
  Requires: homebrew component to be installed first.
EOF
}

install_tools() {
  debug "Installing CLI tools via Homebrew..."
  
  # Check if brew is available
  if ! command -v brew &>/dev/null; then
    err "Homebrew not found in PATH"
    err "Please install homebrew first: ./setup install homebrew"
    return 1
  fi
  
  # Install tools (silently)
  log "Installing zoxide..."
  brew install zoxide >/dev/null 2>&1 || warn "zoxide installation failed or already installed"
  
  log "Installing fzf..."
  brew install fzf >/dev/null 2>&1 || warn "fzf installation failed or already installed"
  
  log "Installing ripgrep..."
  brew install ripgrep >/dev/null 2>&1 || warn "ripgrep installation failed or already installed"
  
  log "Installing bat..."
  brew install bat >/dev/null 2>&1 || warn "bat installation failed or already installed"
  
  log "CLI tools installed successfully"
}

configure_shell() {
  debug "Configuring CLI tools in shell..."
  
  local cli_tools_init='# Initialize zoxide (smart cd)
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

# Initialize fzf
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi'
  
  append_delimited "$HOME/.bashrc" "$cli_tools_init" "cli-tools"
  
  log "CLI tools configured in .bashrc"
}

validate_installation() {
  debug "Validating CLI tools installation..."
  
  local failed=0
  
  # Validate zoxide (required)
  if ! command -v zoxide &>/dev/null; then
    err "zoxide validation failed"
    ((failed++))
  else
    debug "zoxide: $(zoxide --version)"
  fi
  
  # Validate fzf (optional)
  if command -v fzf &>/dev/null; then
    debug "fzf: $(fzf --version)"
  else
    warn "fzf not installed (optional)"
  fi
  
  # Validate ripgrep (optional)
  if command -v rg &>/dev/null; then
    debug "ripgrep: $(rg --version | head -n1)"
  else
    warn "ripgrep not installed (optional)"
  fi
  
  # Validate bat (optional)
  if command -v bat &>/dev/null; then
    debug "bat: $(bat --version)"
  else
    warn "bat not installed (optional)"
  fi
  
  if [[ $failed -gt 0 ]]; then
    warn "$failed required tool(s) failed validation"
    warn "You may need to restart your shell: source ~/.bashrc"
    return 1
  fi
  
  log "CLI tools validated successfully"
  return 0
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
  
  # Verify dependency
  if ! verify_dependencies "$COMPONENT"; then
    exit 1
  fi
  
  debug "Installing CLI tools..."

  install_tools
  configure_shell
  validate_installation

  log "CLI tools installation complete"
  log "Restart your shell or run: source ~/.bashrc"
  log "Try: z <directory>, fzf, rg <pattern>, bat <file>"
}

main "$@"
