#!/usr/bin/env bash
set -euo pipefail

COMPONENT="cloud"
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
  install-cloud-clis.sh [--verbose]

Options:
  --verbose  Show detailed debug information

Description:
  Installs cloud provider CLI tools:
  - AWS CLI (latest)
  - Azure CLI (latest)
  - Google Cloud SDK (latest) - for AI integration
EOF
}

install_aws_cli() {
  if command -v aws &>/dev/null; then
    log "AWS CLI already installed, skipping"
    return 0
  fi
  
  debug "Installing AWS CLI..."
  
  local temp_dir
  temp_dir=$(mktemp -d)
  
  cd "$temp_dir"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install >/dev/null 2>&1
  cd - >/dev/null
  rm -rf "$temp_dir"
  
  local version
  version=$(aws --version 2>/dev/null | awk '{print $1}' | cut -d'/' -f2)
  log "Installed: AWS CLI v$version"
  
  # Configure AWS CLI completion
  local aws_completion='# AWS CLI completion
if command -v aws &>/dev/null; then
  complete -C aws_completer aws
fi'
  
  append_delimited "$HOME/.bashrc" "$aws_completion" "aws-cli"
}

install_azure_cli() {
  if command -v az &>/dev/null; then
    log "Azure CLI already installed, skipping"
    return 0
  fi
  
  debug "Installing Azure CLI..."
  
  # Install prerequisites
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl apt-transport-https lsb-release gnupg >/dev/null 2>&1
  
  # Download and install the signing key
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg >/dev/null 2>&1
  
  # Add the Azure CLI repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list >/dev/null
  
  # Install Azure CLI
  sudo apt-get update -qq
  sudo apt-get install -y -qq azure-cli >/dev/null 2>&1
  
  local version
  version=$(az version 2>/dev/null | grep -oP '"azure-cli": "\K[^"]+' | head -n1)
  log "Installed: Azure CLI v$version"
  
  # Configure Azure CLI completion
  local az_completion='# Azure CLI completion
if command -v az &>/dev/null && [[ -f /etc/bash_completion.d/azure-cli ]]; then
  source /etc/bash_completion.d/azure-cli
fi'
  
  append_delimited "$HOME/.bashrc" "$az_completion" "azure-cli"
}

install_google_cloud_sdk() {
  if command -v gcloud &>/dev/null; then
    log "Google Cloud SDK already installed, skipping"
    return 0
  fi
  
  debug "Installing Google Cloud SDK..."
  
  # Add Google Cloud SDK repository
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  
  # Import Google Cloud public key
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg >/dev/null 2>&1
  
  # Install Google Cloud SDK
  sudo apt-get update -qq
  sudo apt-get install -y -qq google-cloud-cli >/dev/null 2>&1
  
  local version
  version=$(gcloud version 2>/dev/null | grep "Google Cloud SDK" | awk '{print $4}')
  log "Installed: Google Cloud SDK v$version"
  
  # Configure Google Cloud SDK completion
  local gcloud_completion='# Google Cloud SDK completion
if [ -f /usr/share/google-cloud-sdk/completion.bash.inc ]; then
  source /usr/share/google-cloud-sdk/completion.bash.inc
fi'
  
  append_delimited "$HOME/.bashrc" "$gcloud_completion" "google-cloud-sdk"
  
  log "Run 'gcloud init' to configure authentication and project"
}

configure_aliases() {
  debug "Configuring cloud CLI aliases..."
  
  local cloud_aliases='# Cloud CLI aliases
# AWS
alias awsl="aws ec2 describe-instances --query '"'"'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]'"'"' --output table"
alias awss3="aws s3 ls"

# Azure
alias azl="az vm list --output table"
alias azg="az group list --output table"

# Google Cloud
alias gcl="gcloud compute instances list"
alias gcp="gcloud config get-value project"
alias gcai="gcloud ai"'
  
  if [[ -f "$HOME/.bash_aliases" ]]; then
    append_delimited "$HOME/.bash_aliases" "$cloud_aliases" "cloud"
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
  debug "Installing cloud CLI tools..."

  # Ensure dependencies
  require_cmd curl curl
  require_cmd unzip unzip

  install_aws_cli
  install_azure_cli
  install_google_cloud_sdk
  configure_aliases

  log "Cloud CLI tools installation complete"
  log "Restart your shell to enable completions: source ~/.bashrc"
}

main "$@"
