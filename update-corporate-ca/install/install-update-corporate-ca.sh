#!/usr/bin/env bash
set -euo pipefail

PROGRAM="update-corporate-ca"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIN_SRC="$REPO_ROOT/bin/$PROGRAM"
CONFIG_SRC="$REPO_ROOT/config/update-corporate-ca.conf"

# Installation mode: "user" (default) or "system"
INSTALL_MODE="${INSTALL_MODE:-user}"

user_bin="$HOME/.local/bin"
user_cfg_dir="$HOME/.config/update-corporate-ca"
user_cfg="$user_cfg_dir/config"

log()  { printf "%s\n" "$*"; }
warn() { printf "WARNING: %s\n" "$*" >&2; }
err()  { printf "ERROR: %s\n" "$*" >&2; }

ensure_deps() {
  local missing=0
  for c in openssl ca-certificates curl csplit; do
    if ! command -v "$c" >/dev/null 2>&1; then
      warn "Missing dependency: $c"
      missing=1
    fi
  done

  if [[ "$missing" -eq 1 ]]; then
    err "Install missing dependencies using your package manager, e.g.:"
    err "  sudo apt update && sudo apt install -y openssl ca-certificates curl"
    exit 1
  fi
}

install_user() {
  log "Installing $PROGRAM for current user..."
  mkdir -p "$user_bin"
  install -m 0755 "$BIN_SRC" "$user_bin/$PROGRAM"

  mkdir -p "$user_cfg_dir"
  if [[ ! -f "$user_cfg" ]]; then
    install -m 0644 "$CONFIG_SRC" "$user_cfg"
    log "Installed default config at: $user_cfg"
  else
    log "Config already exists at: $user_cfg (leaving unchanged)"
  fi

  if ! echo "$PATH" | grep -q "$user_bin"; then
    warn "$user_bin is not in PATH."
    log "Add this to your shell profile (e.g., ~/.profile or ~/.zshrc):"
    log "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi

  log "Installation complete."
  log "Try:"
  log "  $PROGRAM --print-config"
  log "  $PROGRAM --dry-run"
  log "  $PROGRAM"
}

install_system() {
  log "Installing $PROGRAM system-wide (requires sudo)..."
  sudo install -m 0755 "$BIN_SRC" "/usr/local/bin/$PROGRAM"

  if [[ ! -f "/etc/update-corporate-ca.conf" ]]; then
    sudo install -m 0644 "$CONFIG_SRC" "/etc/update-corporate-ca.conf"
    log "Installed system config at: /etc/update-corporate-ca.conf"
  else
    log "System config already exists at: /etc/update-corporate-ca.conf (leaving unchanged)"
  fi

  log "Installation complete."
  log "Try:"
  log "  $PROGRAM --print-config"
  log "  $PROGRAM --dry-run"
  log "  $PROGRAM"
}

main() {
  ensure_deps

  if [[ ! -f "$BIN_SRC" ]]; then
    err "Cannot find $BIN_SRC"
    exit 1
  fi

  case "$INSTALL_MODE" in
    user) install_user ;;
    system) install_system ;;
    *)
      err "Unknown INSTALL_MODE: $INSTALL_MODE (expected: user|system)"
      exit 2
      ;;
  esac
}

main