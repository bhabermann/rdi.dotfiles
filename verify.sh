#!/usr/bin/env bash
set -euo pipefail

# Verify installed dotfiles components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

VERBOSE=0
FAILED_COUNT=0
SUCCESS_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  verify.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Verifies all installed essential dotfiles components:
  - git: Git configuration and aliases
  - shell: Bash environment and aliases
  - homebrew: Homebrew package manager
  - vfox: Version manager for Node.js, Python, Java
  - Checks configuration files exist
  - Validates delimited sections in dotfiles
  - Runs smoke tests for each component
  - Reports overall health status
EOF
}

# Smoke test definitions for each component
smoke_test_git() {
  debug "Testing git component..."
  
  # Check config file exists
  if [[ ! -f "$HOME/.gitconfig" ]]; then
    err "Git config not found: $HOME/.gitconfig"
    return 1
  fi
  
  # Check for our section
  if ! grep -q "dotfiles:git-aliases" "$HOME/.gitconfig"; then
    warn "Git config missing dotfiles section"
  fi
  
  # Run git version
  if ! validate_command "git --version" "git version" >/dev/null; then
    err "Git validation failed"
    return 1
  fi
  
  # Test an alias
  if ! git config --get alias.co >/dev/null 2>&1; then
    warn "Git alias 'co' not configured"
  fi
  
  log "✓ git: OK"
  return 0
}

smoke_test_shell() {
  debug "Testing shell component..."
  
  # Check bashrc exists
  if [[ ! -f "$HOME/.bashrc" ]]; then
    err "Bashrc not found: $HOME/.bashrc"
    return 1
  fi
  
  # Check for our section
  if ! grep -q "dotfiles:shell" "$HOME/.bashrc"; then
    warn "Bashrc missing dotfiles section"
  fi
  
  # Validate bash syntax
  if ! bash -n "$HOME/.bashrc" 2>/dev/null; then
    err "Bashrc has syntax errors"
    return 1
  fi
  
  # Check aliases file
  if [[ -f "$HOME/.bash_aliases" ]]; then
    if ! bash -n "$HOME/.bash_aliases" 2>/dev/null; then
      warn "Bash aliases has syntax errors"
    fi
  fi
  
  log "✓ shell: OK"
  return 0
}

smoke_test_vfox() {
  debug "Testing vfox component..."
  
  # Check vfox is in PATH
  if ! command -v vfox &>/dev/null; then
    err "vfox not found in PATH"
    return 1
  fi
  
  # Check vfox version
  if ! validate_command "vfox --version" "vfox" >/dev/null; then
    err "vfox validation failed"
    return 1
  fi
  
  # Check for bashrc integration
  if [[ -f "$HOME/.bashrc" ]] && ! grep -q "dotfiles:vfox" "$HOME/.bashrc"; then
    warn "vfox not configured in bashrc"
  fi
  
  # Test installed tools
  local tools_ok=0
  local tools_total=0
  
  if command -v node &>/dev/null; then
    ((tools_ok++))
    debug "Node.js: $(node --version)"
  fi
  ((tools_total++))
  
  if command -v python3 &>/dev/null || command -v python &>/dev/null; then
    ((tools_ok++))
    debug "Python: $(python3 --version 2>/dev/null || python --version 2>/dev/null)"
  fi
  ((tools_total++))
  
  if command -v java &>/dev/null; then
    ((tools_ok++))
    debug "Java: $(java -version 2>&1 | head -n1)"
  fi
  ((tools_total++))
  
  log "✓ vfox: OK ($tools_ok/$tools_total tools available)"
  return 0
}

smoke_test_homebrew() {
  debug "Testing homebrew component..."
  
  # Check brew is in PATH
  if ! command -v brew &>/dev/null; then
    err "brew not found in PATH"
    return 1
  fi
  
  # Check brew version
  if ! validate_command "brew --version" "Homebrew" >/dev/null; then
    err "Homebrew validation failed"
    return 1
  fi
  
  # Check for bashrc integration
  if [[ -f "$HOME/.bashrc" ]] && ! grep -q "dotfiles:homebrew" "$HOME/.bashrc"; then
    warn "Homebrew not configured in bashrc"
  fi
  
  log "✓ homebrew: OK"
  return 0
}

# Main verification logic
verify_component() {
  local component="$1"
  local status="$2"
  
  debug "Verifying: $component (status: $status)"
  
  # Skip if not installed
  if [[ "$status" == "null" ]]; then
    debug "Component not installed: $component"
    return 0
  fi
  
  # Run smoke test
  if "smoke_test_$component"; then
    ((SUCCESS_COUNT++))
  else
    ((FAILED_COUNT++))
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

  log "Verifying dotfiles installation..."
  
  # Ensure jq is installed
  ensure_jq
  
  # Check if tracking file exists
  if [[ ! -f "$DOTFILES_INSTALLED" ]]; then
    warn "No installation tracking found: $DOTFILES_INSTALLED"
    log "Run './install.sh' to set up dotfiles"
    exit 1
  fi
  
  # Get all installed components
  local components
  components=$(jq -r 'keys[]' "$DOTFILES_INSTALLED")
  
  # Verify each component
  for component in $components; do
    local status
    status=$(read_component_status "$component")
    verify_component "$component" "$status"
  done
  
  # Report results
  echo ""
  log "Verification complete:"
  log "  ✓ Success: $SUCCESS_COUNT component(s)"
  
  if [[ $FAILED_COUNT -gt 0 ]]; then
    err "  ✗ Failed: $FAILED_COUNT component(s)"
    echo ""
    warn "Run './update.sh' or './install.sh --interactive' to fix issues"
    exit 1
  fi
  
  log "All components are healthy! ✨"
  exit 0
}

main "$@"
