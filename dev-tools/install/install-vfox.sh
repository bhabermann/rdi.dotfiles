#!/usr/bin/env bash
set -euo pipefail

COMPONENT="vfox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../../lib/dependencies.sh
source "$ROOT_DIR/lib/dependencies.sh"

VERBOSE=0
VERSIONS_YAML="$SCRIPT_DIR/../config/versions.yaml"
VFOX_DIR="$HOME/.vfox"

usage() {
  cat <<'EOF'
Usage:
  install-vfox.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs vfox (version fox) - a universal version manager.
  Configures Node.js, Python, and Java from versions.yaml.
  
  Requires: shell component to be installed first.
EOF
}

install_vfox() {
  if command -v vfox &>/dev/null; then
    log "vfox already installed, skipping download"
    return 0
  fi
  
  debug "Downloading and installing vfox..."
  
  # Install vfox
  curl -fsSL https://raw.githubusercontent.com/version-fox/vfox/main/install.sh | bash
  
  if [[ ! -f "$VFOX_DIR/bin/vfox" ]]; then
    err "vfox installation failed"
    return 1
  fi
  
  log "vfox installed to: $VFOX_DIR"
}

configure_shell() {
  debug "Configuring vfox in shell..."
  
  local vfox_init='# Initialize vfox
export PATH="$HOME/.vfox/bin:$PATH"
eval "$(vfox activate bash)"'
  
  append_delimited "$HOME/.bashrc" "$vfox_init" "vfox"
  
  # Source it in current session
  export PATH="$HOME/.vfox/bin:$PATH"
  eval "$(vfox activate bash)" || true
  
  log "vfox configured in .bashrc"
}

install_tools() {
  debug "Installing tools from versions.yaml..."
  
  if [[ ! -f "$VERSIONS_YAML" ]]; then
    err "versions.yaml not found: $VERSIONS_YAML"
    return 1
  fi
  
  # Parse YAML and install each tool
  local tools=("nodejs" "python" "java")
  
  for tool in "${tools[@]}"; do
    local version
    version=$(parse_yaml "$VERSIONS_YAML" "$tool")
    
    if [[ -z "$version" ]]; then
      warn "No version specified for $tool, skipping"
      continue
    fi
    
    debug "Installing $tool@$version..."
    
    # Add plugin if not already added
    if ! vfox list | grep -q "^$tool"; then
      vfox add "$tool" || warn "Failed to add plugin: $tool"
    fi
    
    # Install version
    if [[ "$version" == "latest" ]]; then
      vfox install "$tool@latest" || warn "Failed to install $tool@latest"
    else
      vfox install "$tool@$version" || warn "Failed to install $tool@$version"
    fi
    
    # Set as global version
    vfox use -g "$tool@$version" || warn "Failed to set global version: $tool@$version"
    
    log "Installed: $tool@$version"
  done
}

validate_installation() {
  debug "Validating tool installations..."
  
  local failed=0
  
  # Validate Node.js
  if ! node --version &>/dev/null; then
    warn "Node.js validation failed"
    ((failed++))
  else
    debug "Node.js: $(node --version)"
  fi
  
  # Validate Python
  if ! python --version &>/dev/null && ! python3 --version &>/dev/null; then
    warn "Python validation failed"
    ((failed++))
  else
    debug "Python: $(python3 --version 2>/dev/null || python --version)"
  fi
  
  # Validate Java
  if ! java -version &>/dev/null; then
    warn "Java validation failed"
    ((failed++))
  else
    debug "Java: $(java -version 2>&1 | head -n1)"
  fi
  
  if [[ $failed -gt 0 ]]; then
    warn "$failed tool(s) failed validation"
    warn "You may need to restart your shell: source ~/.bashrc"
    return 1
  fi
  
  log "All tools validated successfully"
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
  
  debug "Installing vfox and development tools..."

  install_vfox
  configure_shell
  install_tools
  validate_installation

  log "vfox installation complete"
  log "Restart your shell or run: source ~/.bashrc"
}

main "$@"
