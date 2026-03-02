#!/usr/bin/env bash
set -euo pipefail

COMPONENT="kubernetes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=../../lib/dependencies.sh
source "$ROOT_DIR/lib/dependencies.sh"

VERBOSE=0
VERSIONS_YAML="$SCRIPT_DIR/../config/versions.yaml"

usage() {
  cat <<'EOF'
Usage:
  install-k8s-tools.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs Kubernetes tools:
  - kubectl: Kubernetes command-line tool
  - helm: Kubernetes package manager
  - k9s: Kubernetes CLI UI
  
  Requires: cli-tools component (for dependencies)
EOF
}

install_kubectl() {
  local version="1.29.2"
  
  if command -v kubectl &>/dev/null; then
    log "kubectl already installed, skipping"
    return 0
  fi
  
  debug "Installing kubectl v$version..."
  
  local temp_dir
  temp_dir=$(mktemp -d)
  
  cd "$temp_dir"
  wget -q "https://dl.k8s.io/release/v$version/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo install -m 0755 kubectl /usr/local/bin/kubectl
  cd - >/dev/null
  rm -rf "$temp_dir"
  
  log "Installed: kubectl v$version"
  
  # Configure kubectl completion
  local kubectl_completion='# kubectl completion
if command -v kubectl &>/dev/null; then
  source <(kubectl completion bash)
  complete -o default -F __start_kubectl k
fi'
  
  append_delimited "$HOME/.bashrc" "$kubectl_completion" "kubectl"
}

install_helm() {
  if command -v helm &>/dev/null; then
    log "helm already installed, skipping"
    return 0
  fi
  
  debug "Installing helm..."
  
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null 2>&1
  
  local version
  version=$(helm version --short 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -n1)
  log "Installed: helm $version"
  
  # Configure helm completion
  local helm_completion='# helm completion
if command -v helm &>/dev/null; then
  source <(helm completion bash)
fi'
  
  append_delimited "$HOME/.bashrc" "$helm_completion" "helm"
}

install_k9s() {
  if command -v k9s &>/dev/null; then
    log "k9s already installed, skipping"
    return 0
  fi
  
  debug "Installing k9s..."
  
  local temp_dir
  temp_dir=$(mktemp -d)
  
  cd "$temp_dir"
  
  # Get latest release URL
  local latest_url
  latest_url=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"browser_download_url": "\K[^"]*Linux_amd64\.tar\.gz' | head -n1)
  
  if [[ -z "$latest_url" ]]; then
    warn "Could not find k9s latest release, skipping"
    return 0
  fi
  
  wget -q "$latest_url" -O k9s.tar.gz
  tar -xzf k9s.tar.gz k9s
  sudo install -m 0755 k9s /usr/local/bin/k9s
  cd - >/dev/null
  rm -rf "$temp_dir"
  
  local version
  version=$(k9s version --short 2>/dev/null | head -n1 | awk '{print $2}')
  log "Installed: k9s $version"
}

configure_aliases() {
  debug "Configuring Kubernetes aliases..."
  
  local k8s_aliases='# Kubernetes aliases
alias k="kubectl"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"
alias kl="kubectl logs"
alias kx="kubectl exec -it"
alias kctx="kubectl config use-context"
alias kns="kubectl config set-context --current --namespace"'
  
  if [[ -f "$HOME/.bash_aliases" ]]; then
    append_delimited "$HOME/.bash_aliases" "$k8s_aliases" "kubernetes"
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
  
  # Verify dependency
  if ! verify_dependencies "$COMPONENT"; then
    exit 1
  fi
  
  debug "Installing Kubernetes tools..."

  # Ensure curl and wget are available
  require_cmd curl curl
  require_cmd wget wget

  install_kubectl
  install_helm
  install_k9s
  configure_aliases

  log "Kubernetes tools installation complete"
  log "Restart your shell to enable completions: source ~/.bashrc"
}

main "$@"
