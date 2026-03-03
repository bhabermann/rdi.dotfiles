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
  Configures Node.js, Python, Go, .NET, and Java from versions.yaml.
  
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
  
  # Refresh PATH to pick up newly installed vfox
  export PATH="/usr/local/bin:$HOME/.vfox/bin:$PATH"
  
  if ! command -v vfox &>/dev/null; then
    err "vfox installation failed"
    return 1
  fi
  
  log "vfox installed: $(command -v vfox)"
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

ensure_python_build_deps() {
  debug "Ensuring Python build dependencies are installed..."

  local packages=(
    build-essential
    libssl-dev
    zlib1g-dev
    libbz2-dev
    libreadline-dev
    libsqlite3-dev
    curl
    libncursesw5-dev
    xz-utils
    tk-dev
    libxml2-dev
    libxmlsec1-dev
    libffi-dev
    liblzma-dev
  )

  # Check if build-essential is already installed as a quick proxy
  if dpkg -s build-essential &>/dev/null; then
    debug "Python build dependencies already installed"
    return 0
  fi

  log "Installing Python build dependencies..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq "${packages[@]}" >/dev/null 2>&1

  if ! dpkg -s build-essential &>/dev/null; then
    err "Failed to install Python build dependencies"
    return 1
  fi

  log "Python build dependencies installed"
}

vfox_install_with_retry() {
  local tool="$1"
  local version="$2"
  local max_retries=3
  local retry_delay=5

  for ((attempt = 1; attempt <= max_retries; attempt++)); do
    if vfox install "$tool@$version"; then
      return 0
    fi
    if [[ $attempt -lt $max_retries ]]; then
      warn "Failed to install $tool@$version (attempt $attempt/$max_retries), retrying in ${retry_delay}s..."
      sleep "$retry_delay"
    fi
  done

  warn "Failed to install $tool@$version after $max_retries attempts"
  return 1
}

install_tools() {
  debug "Installing tools from versions.yaml..."
  
  if [[ ! -f "$VERSIONS_YAML" ]]; then
    err "versions.yaml not found: $VERSIONS_YAML"
    return 1
  fi
  
  # Parse YAML and install each tool
  local tools=("nodejs" "python" "golang" "dotnet" "java")
  
  for tool in "${tools[@]}"; do
    local version
    version=$(parse_yaml "$VERSIONS_YAML" "$tool")
    
    if [[ -z "$version" ]]; then
      warn "No version specified for $tool, skipping"
      continue
    fi
    
    debug "Installing $tool@$version..."

    # Ensure build dependencies for Python (compiled from source by vfox/pyenv)
    if [[ "$tool" == "python" ]]; then
      ensure_python_build_deps
    fi
    
    # Add plugin if not already added
    if ! vfox list | grep -q "^$tool"; then
      vfox add "$tool" || warn "Failed to add plugin: $tool"
    fi
    
    # Install version with retry for transient network failures
    if ! vfox_install_with_retry "$tool" "$version"; then
      warn "Skipping $tool — install failed after retries"
      continue
    fi
    
    # Set as global version
    vfox use -g "$tool@$version" || warn "Failed to set global version: $tool@$version"
    
    log "Installed: $tool@$version"
  done
}

validate_installation() {
  debug "Validating tool installations..."

  # Re-activate vfox shims so binaries are on PATH in this session
  eval "$(vfox activate bash 2>/dev/null)" || true
  # Also add the vfox internal current bin to PATH as a fallback
  export PATH="$HOME/.version-fox/shims:$PATH"

  local failed=0
  local installed_tools=()

  # Validate Node.js
  if vfox list nodejs 2>/dev/null | grep -q "v"; then
    installed_tools+=("nodejs")
    if node --version &>/dev/null; then
      debug "Node.js: $(node --version)"
    else
      debug "Node.js installed via vfox but not on PATH (will work after shell restart)"
    fi
  else
    warn "Node.js not installed by vfox"
    ((failed++)) || true
  fi

  # Validate Python
  if vfox list python 2>/dev/null | grep -q "v"; then
    installed_tools+=("python")
    if python3 --version &>/dev/null || python --version &>/dev/null; then
      debug "Python: $(python3 --version 2>/dev/null || python --version)"
    else
      debug "Python installed via vfox but not on PATH (will work after shell restart)"
    fi
  else
    warn "Python not installed by vfox"
    ((failed++)) || true
  fi

  # Validate Go
  if vfox list golang 2>/dev/null | grep -q "v"; then
    installed_tools+=("golang")
    if go version &>/dev/null; then
      debug "Go: $(go version)"
    else
      debug "Go installed via vfox but not on PATH (will work after shell restart)"
    fi
  else
    warn "Go (golang) not installed by vfox"
    ((failed++)) || true
  fi

  # Validate .NET
  if vfox list dotnet 2>/dev/null | grep -q "v"; then
    installed_tools+=("dotnet")
    if dotnet --info &>/dev/null; then
      debug "dotnet: $(dotnet --info | head -n1)"
    else
      debug ".NET installed via vfox but not on PATH (will work after shell restart)"
    fi
  else
    warn ".NET (dotnet) not installed by vfox"
    ((failed++)) || true
  fi

  # Validate Java
  if vfox list java 2>/dev/null | grep -q "v"; then
    installed_tools+=("java")
    if java -version &>/dev/null; then
      debug "Java: $(java -version 2>&1 | head -n1)"
    else
      debug "Java installed via vfox but not on PATH (will work after shell restart)"
    fi
  else
    # Java is optional — network issues are common with large JDK downloads
    warn "Java not installed by vfox (may be due to network issues)"
  fi

  if [[ ${#installed_tools[@]} -eq 0 ]]; then
    err "No tools were installed by vfox"
    return 1
  fi

  if [[ $failed -gt 0 ]]; then
    warn "$failed required tool(s) failed validation"
    warn "You may need to restart your shell: source ~/.bashrc"
    return 1
  fi

  log "vfox tools validated: ${installed_tools[*]}"
  log "Note: some tools may require a shell restart to appear on PATH"
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

  # Show installed versions summary
  echo
  echo "==== vfox Installed Versions ===="
  vfox current || true
  echo "Node.js:   $(node --version 2>/dev/null || echo 'not on PATH')"
  echo "Python:    $(python3 --version 2>/dev/null || python --version 2>/dev/null || echo 'not on PATH')"
  echo "Go:        $(go version 2>/dev/null || echo 'not on PATH')"
  echo ".NET:      $(dotnet --version 2>/dev/null || echo 'not on PATH')"
  echo "Java:      $(java -version 2>&1 | head -n1 2>/dev/null || echo 'not on PATH')"
  echo "==============================="

  log "vfox installation complete"
  log "Restart your shell or run: source ~/.bashrc"
}

main "$@"
