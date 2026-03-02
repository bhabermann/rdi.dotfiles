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
  Verifies all installed dotfiles components:
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

smoke_test_cli_tools() {
  debug "Testing cli-tools component..."
  
  local tools_ok=0
  local tools_total=4
  
  # Check each tool
  if command -v fzf &>/dev/null; then
    ((tools_ok++))
    debug "fzf: $(fzf --version | awk '{print $1}')"
  else
    warn "fzf not found"
  fi
  
  if command -v rg &>/dev/null; then
    ((tools_ok++))
    debug "ripgrep: $(rg --version | head -n1 | awk '{print $2}')"
  else
    warn "ripgrep not found"
  fi
  
  if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
    ((tools_ok++))
    debug "bat: $(bat --version 2>/dev/null || batcat --version 2>/dev/null | awk '{print $2}')"
  else
    warn "bat not found"
  fi
  
  if command -v exa &>/dev/null; then
    ((tools_ok++))
    debug "exa: $(exa --version | head -n1 | awk '{print $2}')"
  else
    warn "exa not found (optional)"
  fi
  
  if [[ $tools_ok -eq 0 ]]; then
    err "No CLI tools found"
    return 1
  fi
  
  log "✓ cli-tools: OK ($tools_ok/$tools_total tools available)"
  return 0
}

smoke_test_kubernetes() {
  debug "Testing kubernetes component..."
  
  local tools_ok=0
  local tools_total=3
  
  # Check kubectl
  if command -v kubectl &>/dev/null; then
    if validate_command "kubectl version --client" "Client Version" >/dev/null; then
      ((tools_ok++))
      debug "kubectl: $(kubectl version --client --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -n1)"
    fi
  else
    warn "kubectl not found"
  fi
  
  # Check helm
  if command -v helm &>/dev/null; then
    if validate_command "helm version --short" "v" >/dev/null; then
      ((tools_ok++))
      debug "helm: $(helm version --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+')"
    fi
  else
    warn "helm not found"
  fi
  
  # Check k9s
  if command -v k9s &>/dev/null; then
    ((tools_ok++))
    debug "k9s: $(k9s version --short 2>/dev/null | head -n1 | awk '{print $2}')"
  else
    warn "k9s not found"
  fi
  
  if [[ $tools_ok -eq 0 ]]; then
    err "No Kubernetes tools found"
    return 1
  fi
  
  log "✓ kubernetes: OK ($tools_ok/$tools_total tools available)"
  return 0
}

smoke_test_cloud() {
  debug "Testing cloud component..."
  
  local tools_ok=0
  local tools_total=3
  
  # Check AWS CLI
  if command -v aws &>/dev/null; then
    if validate_command "aws --version" "aws-cli" >/dev/null; then
      ((tools_ok++))
      debug "AWS CLI: $(aws --version 2>/dev/null | awk '{print $1}' | cut -d'/' -f2)"
    fi
  else
    warn "AWS CLI not found"
  fi
  
  # Check Azure CLI
  if command -v az &>/dev/null; then
    if az version &>/dev/null; then
      ((tools_ok++))
      debug "Azure CLI: $(az version 2>/dev/null | grep -oP '"azure-cli": "\K[^"]+' | head -n1)"
    fi
  else
    warn "Azure CLI not found"
  fi
  
  # Check Google Cloud SDK
  if command -v gcloud &>/dev/null; then
    if validate_command "gcloud version" "Google Cloud SDK" >/dev/null; then
      ((tools_ok++))
      debug "Google Cloud SDK: $(gcloud version 2>/dev/null | grep "Google Cloud SDK" | awk '{print $4}')"
    fi
  else
    warn "Google Cloud SDK not found"
  fi
  
  if [[ $tools_ok -eq 0 ]]; then
    err "No cloud CLI tools found"
    return 1
  fi
  
  log "✓ cloud: OK ($tools_ok/$tools_total tools available)"
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
