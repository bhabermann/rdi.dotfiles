#!/usr/bin/env bash
set -euo pipefail

PROGRAM="update-corporate-ca"
SCRIPT_REL="../bin/update-corporate-ca"
CONFIG_REL="../config/update-corporate-ca.conf"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$ROOT_DIR/$SCRIPT_REL"
CONFIG_SRC="$ROOT_DIR/$CONFIG_REL"

log()  { printf "%s\n" "$*"; }
warn() { printf "WARNING: %s\n" "$*" >&2; }
err()  { printf "ERROR: %s\n" "$*" >&2; }

require_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    sudo -v
  fi
}

install_deps_apt() {
  log "Installing dependencies using apt..."
  sudo apt-get update -y
  sudo apt-get install -y openssl ca-certificates curl
}

ensure_deps() {
  local missing=()
  for cmd in openssl curl; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
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
  sudo sed -i 's/\r$//' "/usr/local/bin/$PROGRAM" || true
  sudo chmod +x "/usr/local/bin/$PROGRAM"

  if [[ -f "/etc/update-corporate-ca.conf" ]]; then
    sudo sed -i 's/\r$//' "/etc/update-corporate-ca.conf" || true
  fi
}

main() {
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

  require_sudo
  ensure_deps

  log "Installing $PROGRAM as a system command..."

  sudo install -m 0755 "$SCRIPT_SRC" "/usr/local/bin/$PROGRAM"

  if [[ ! -f "/etc/update-corporate-ca.conf" ]]; then
    sudo install -m 0644 "$CONFIG_SRC" "/etc/update-corporate-ca.conf"
    log "Installed config: /etc/update-corporate-ca.conf"
  else
    log "Config already exists: /etc/update-corporate-ca.conf (leaving unchanged)"
    log "To update it, edit the file manually or replace it."
  fi

  normalize_lf

  log "Done."
  log ""
  log "Try:"
  log "  $PROGRAM help"
  log "  $PROGRAM --dry-run"
  log "  $PROGRAM"
}

main