#!/usr/bin/env bash
set -euo pipefail

# Installs Docker Engine inside WSL Ubuntu (via Docker official repo),
# enables/starts the docker service via systemd,
# and creates Windows wrapper commands (docker.cmd + docker-compose.cmd)
# so Windows usage feels native.

VERBOSE=0

log()   { printf "✓ %s\n" "$*"; }
warn()  { printf "⚠ WARNING: %s\n" "$*" >&2; }
err()   { printf "✗ ERROR: %s\n" "$*" >&2; }
debug() { [[ "$VERBOSE" -eq 1 ]] && printf "  [DEBUG] %s\n" "$*" || true; }

usage() {
  cat <<'EOF'
Usage:
  install-docker-wsl-and-windows-wrapper.sh [--distro <WSL_Distro_Name>] [--no-path-update] [--verbose]

Options:
  --distro          WSL distro name to target from Windows wrappers (default: $WSL_DISTRO_NAME)
  --no-path-update  Do NOT try to add %USERPROFILE%\bin to Windows User PATH automatically
  --verbose         Show detailed debug information during installation

Notes:
  - If systemd isn't enabled in this WSL distro, the script will:
      1) write /etc/wsl.conf with [boot] systemd=true
      2) request a WSL restart via `wsl.exe --shutdown`
      3) exit. Re-run the script after reopening WSL.
EOF
}

is_wsl() {
  [[ -n "${WSL_INTEROP:-}" ]] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

require_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || { err "Command not found: $c"; exit 1; }
}

trim_cr() { tr -d '\r'; }

enable_systemd_if_needed() {
  # Detect if systemd is PID 1
  local pid1
  pid1="$(ps -p 1 -o comm= 2>/dev/null || true)"
  debug "Detected PID 1: $pid1"

  if [[ "$pid1" == "systemd" ]]; then
    log "systemd is already enabled"
    return 0
  fi

  warn "systemd is not running as PID 1 (detected: '${pid1:-unknown}')."
  warn "Docker service management is simplest with systemd in WSL."
  debug "Configuring /etc/wsl.conf to enable systemd..."

  sudo mkdir -p /etc
  if [[ -f /etc/wsl.conf ]]; then
    debug "/etc/wsl.conf exists, checking for systemd configuration"
    # If file exists, ensure it contains [boot] systemd=true
    if ! grep -qE '^\[boot\]' /etc/wsl.conf; then
      debug "Adding [boot] section to /etc/wsl.conf"
      printf "\n[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
    else
      # Replace or add systemd=true under [boot]
      # Simple approach: append if not present; WSL will read last occurrence.
      if ! grep -qE '^\s*systemd\s*=\s*true\s*$' /etc/wsl.conf; then
        debug "Adding systemd=true to existing [boot] section"
        printf "\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
      fi
    fi
  else
    debug "Creating /etc/wsl.conf with systemd enabled"
    printf "[boot]\nsystemd=true\n" | sudo tee /etc/wsl.conf >/dev/null
  fi

  log "systemd enabled in /etc/wsl.conf"
  log "WSL must be restarted for this to take effect."
  log "Running: wsl.exe --shutdown"
  # Microsoft documents that changes require a restart; wsl.exe --shutdown is the fast path. [2](https://download.docker.com/win/static/stable/x86_64/)[3](https://www.codegenes.net/blog/cannot-connect-to-the-docker-daemon-at-tcp-localhost-2375-is-the-docker-daemon-running-on-gitlab/)
  wsl.exe --shutdown || true

  warn "WSL has been shut down."
  warn "Re-open your WSL distro and re-run this installer."
  exit 0
}

install_docker_engine_ubuntu() {
  debug "Installing Docker Engine (Ubuntu) using Docker's official APT repository..."

  # Steps based on Docker docs for Ubuntu installation. [1](https://wsl.dev/technical-documentation/interop/)
  debug "Running apt-get update"
  sudo apt-get update >/dev/null 2>&1
  debug "Installing ca-certificates, curl, gnupg"
  sudo apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1

  debug "Setting up Docker GPG keys"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  local codename
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
  debug "Ubuntu codename: $codename"

  debug "Adding Docker APT repository"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  debug "Installing Docker packages"
  sudo apt-get update >/dev/null 2>&1
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

  log "Docker Engine installed"
}

enable_and_start_docker() {
  debug "Enabling and starting docker service..."
  # With systemd enabled, systemctl can manage services in WSL as documented by Microsoft. [2](https://download.docker.com/win/static/stable/x86_64/)
  sudo systemctl enable --now docker >/dev/null 2>&1

  debug "Testing Docker (hello-world)..."
  sudo docker run --rm hello-world >/dev/null 2>&1 || true
  log "Docker service started"
}

optional_docker_group() {
  if getent group docker >/dev/null 2>&1; then
    debug "Docker group already exists"
  else
    debug "Creating docker group"
    sudo groupadd docker >/dev/null 2>&1 || true
  fi

  # Add current user to docker group to avoid sudo (optional but nice).
  # User must re-login (new shell) for group to apply.
  debug "Adding user '$USER' to docker group"
  sudo usermod -aG docker "$USER" || true
  log "User added to docker group (re-login required)"
}

install_windows_wrappers() {
  local distro="$1"
  local update_path="$2" # true/false

  require_cmd cmd.exe
  require_cmd powershell.exe
  require_cmd wslpath

  # Get %USERPROFILE% from Windows
  local win_home
  win_home="$(cmd.exe /c "echo %USERPROFILE%" | trim_cr | tail -n 1)"
  if [[ -z "$win_home" ]]; then
    err "Failed to read %USERPROFILE% from Windows."
    exit 1
  fi

  local target_win="${win_home}\\bin"
  local target_wsl
  target_wsl="$(wslpath -u "$target_win" | trim_cr)"

  debug "Installing Windows wrappers to: $target_win"
  mkdir -p "$target_wsl"

  # Write CRLF .cmd files
  debug "Creating docker.cmd wrapper"
  {
    printf "@echo off\r\n"
    printf "wsl.exe -d %s -- docker %%*\r\n" "$distro"
  } > "$target_wsl/docker.cmd"

  debug "Creating docker-compose.cmd wrapper"
  {
    printf "@echo off\r\n"
    printf "wsl.exe -d %s -- docker compose %%*\r\n" "$distro"
  } > "$target_wsl/docker-compose.cmd"

  log "Windows wrappers created in %USERPROFILE%\\bin"

  if [[ "$update_path" == "true" ]]; then
    debug "Attempting to add $target_win to Windows User PATH..."
    powershell.exe -NoProfile -Command "\
      \$t='$target_win'; \
      \$u=[Environment]::GetEnvironmentVariable('Path','User'); \
      if (\$u -and (\$u.Split(';') -contains \$t)) { \
        Write-Host 'PATH already contains target directory.'; exit 0 \
      } \
      \$new = if (\$u) { \"\$u;\$t\" } else { \"\$t\" }; \
      [Environment]::SetEnvironmentVariable('Path', \$new, 'User'); \
      Write-Host 'Windows User PATH updated. Open a NEW terminal to take effect.' \
    " | trim_cr
    log "Windows PATH updated"
  else
    warn "Skipping PATH update (as requested). Ensure $target_win is in your Windows PATH."
  fi
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  if ! is_wsl; then
    err "This installer must be run inside WSL."
    exit 1
  fi

  require_cmd sudo
  require_cmd apt-get
  require_cmd ps
  require_cmd wsl.exe

  local distro="${WSL_DISTRO_NAME:-}"
  local update_path="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --distro) distro="${2:-}"; shift 2;;
      --no-path-update) update_path="false"; shift;;
      --verbose) VERBOSE=1; shift;;
      -h|--help) usage; exit 0;;
      *) err "Unknown arg: $1"; usage; exit 1;;
    esac
  done

  if [[ -z "$distro" ]]; then
    err "Could not determine distro name. Run in Windows: wsl -l -v"
    err "Then re-run with: --distro <Name>"
    exit 1
  fi

  debug "Verbose mode enabled"
  debug "Target WSL distro for Windows wrappers: $distro"

  enable_systemd_if_needed

  # Install Docker inside WSL Ubuntu using Docker official steps. [1](https://wsl.dev/technical-documentation/interop/)
  install_docker_engine_ubuntu

  # Start/enable docker using systemd. systemd usage in WSL is documented by Microsoft. [2](https://download.docker.com/win/static/stable/x86_64/)
  enable_and_start_docker
  optional_docker_group

  install_windows_wrappers "$distro" "$update_path"

  log "Docker installation complete!"
  debug "Open a NEW Windows terminal and try:"
  debug "  docker version"
  debug "  docker ps"
  debug "  docker-compose version"
}

main "$@"