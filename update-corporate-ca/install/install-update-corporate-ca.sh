#!/usr/bin/env bash
set -euo pipefail

PROGRAM="update-corporate-ca"
SCRIPT_REL="../bin/update-corporate-ca"
CONFIG_REL="../config/update-corporate-ca.conf"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$ROOT_DIR/$SCRIPT_REL"
CONFIG_SRC="$ROOT_DIR/$CONFIG_REL"

VERBOSE=0

log()   { printf "✓ %s\n" "$*"; }
warn()  { printf "⚠ WARNING: %s\n" "$*" >&2; }
err()   { printf "✗ ERROR: %s\n" "$*" >&2; }
debug() { [[ "$VERBOSE" -eq 1 ]] && printf "  [DEBUG] %s\n" "$*" || true; }

require_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    # Prefer non-interactive sudo for automation contexts.
    if ! sudo -n true 2>/dev/null; then
      if [[ -t 0 ]]; then
        sudo -v
      else
        err "sudo access is required but no non-interactive sudo is available."
        err "Run in an interactive shell to authenticate, or configure NOPASSWD."
        exit 1
      fi
    fi
  fi
}

install_deps_apt() {
  debug "Installing dependencies using apt..."
  sudo apt-get update -y >/dev/null 2>&1
  sudo apt-get install -y openssl ca-certificates curl >/dev/null 2>&1
  log "Dependencies installed via apt"
}

ensure_deps() {
  local missing=()
  for cmd in openssl curl; do
    debug "Checking for command: $cmd"
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    log "Dependencies verified (openssl, curl)"
    return 0
  fi

  warn "Missing dependencies: ${missing[*]}"

  if command -v apt-get >/dev/null 2>&1; then
    install_deps_apt
  else
    err "Automatic dependency installation is only implemented for apt-based distros."
    err "Please install dependencies manually: openssl, ca-certificates, curl"
    exit 1
  fi
}

normalize_lf() {
  # Normalize installed binary + config to LF to prevent bash\r and config $'\r' issues
  debug "Normalizing line endings for installed files"
  sudo sed -i 's/\r$//' "/usr/local/bin/$PROGRAM" || true
  sudo chmod +x "/usr/local/bin/$PROGRAM"

  if [[ -f "/etc/update-corporate-ca.conf" ]]; then
    sudo sed -i 's/\r$//' "/etc/update-corporate-ca.conf" || true
  fi
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose)
        VERBOSE=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
Usage:
  install-update-corporate-ca.sh [--verbose]

Options:
  --verbose  Show detailed debug information during installation

Description:
  Installs the update-corporate-ca script to /usr/local/bin and
  the configuration file to /etc/update-corporate-ca.conf
EOF
        exit 0
        ;;
      *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  debug "Verbose mode enabled"

  # Soft warning if running from /mnt/c (WSL Windows mount)
  if [[ "$ROOT_DIR" == /mnt/* ]]; then
    warn "You are running this installer from a Windows-mounted path ($ROOT_DIR)."
    warn "Recommended: clone and run from Linux filesystem (e.g., ~/.dotfiles)."
  fi

  if [[ ! -f "$SCRIPT_SRC" ]]; then
    err "Cannot find script source: $SCRIPT_SRC"
    exit 1
  fi
  if [[ ! -f "$CONFIG_SRC" ]]; then
    err "Cannot find config source: $CONFIG_SRC"
    exit 1
  fi

  debug "Script source: $SCRIPT_SRC"
  debug "Config source: $CONFIG_SRC"

  require_sudo
  ensure_deps

  debug "Installing $PROGRAM to /usr/local/bin/$PROGRAM"
  sudo install -m 0755 "$SCRIPT_SRC" "/usr/local/bin/$PROGRAM"
  log "Script installed to /usr/local/bin/$PROGRAM"

  if [[ ! -f "/etc/update-corporate-ca.conf" ]]; then
    debug "Installing config to /etc/update-corporate-ca.conf"
    sudo install -m 0644 "$CONFIG_SRC" "/etc/update-corporate-ca.conf"
    log "Config installed to /etc/update-corporate-ca.conf"
  else
    debug "Config already exists at /etc/update-corporate-ca.conf (leaving unchanged)"
  fi

  normalize_lf

  log "Installation complete!"
  debug "Try:"
  debug "  $PROGRAM --help"
  debug "  $PROGRAM --dry-run"
  debug "  $PROGRAM"
}

main "$@"
