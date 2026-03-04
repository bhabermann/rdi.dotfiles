#!/usr/bin/env bash
set -euo pipefail

# Run setup in a plain ubuntu:24.04 container.
# WSL-only components (docker + ca-updater) are pre-seeded as installed.

IMAGE="ubuntu:24.04"
REPO_DIR_LINUX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR_DOCKER="$REPO_DIR_LINUX"

# Git Bash/MSYS needs Windows path for docker -v mounts.
case "${OSTYPE:-}" in
  msys*|cygwin*)
    REPO_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -W)"
    ;;
esac

echo "==> Running plain Ubuntu 24.04 setup test in Docker"
echo "==> Image: $IMAGE"
echo "==> Repo:  $REPO_DIR_DOCKER"

docker run --rm \
  -v "$REPO_DIR_DOCKER:/workspace:ro" \
  "$IMAGE" \
  bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get install -y -qq sudo curl ca-certificates git bash jq openssl >/dev/null

    useradd -m -s /bin/bash testuser
    echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser
    chmod 440 /etc/sudoers.d/testuser

    cp -a /workspace /home/testuser/.dotfiles
    chown -R testuser:testuser /home/testuser/.dotfiles

    # Install ca-updater command so pre-vfox CA refresh can run.
    install -m 0755 /workspace/update-corporate-ca/bin/update-corporate-ca /usr/local/bin/update-corporate-ca
    install -m 0644 /workspace/update-corporate-ca/config/update-corporate-ca.conf /etc/update-corporate-ca.conf

    sudo -u testuser -H bash --noprofile --norc -c "
      set -euo pipefail
      cd \$HOME/.dotfiles

      # WSL-only components are not meaningful in plain Docker.
      cat > \$HOME/.dotfiles-installed <<'\"'\"'JSON'\"'\"'
{\"docker\":{\"installed_at\":\"pre-seeded\",\"version\":\"skip\",\"status\":\"ok\",\"backup_dir\":\"\"},\"ca-updater\":{\"installed_at\":\"pre-seeded\",\"version\":\"skip\",\"status\":\"ok\",\"backup_dir\":\"\"}}
JSON

      ./setup --verbose --log install

      # In plain Docker we pre-seed docker only to skip WSL-specific install.
      # Remove it from tracking so verify does not require docker CLI/daemon.
      tmp_file=\$(mktemp)
      jq '"'"'del(.docker)'"'"' \$HOME/.dotfiles-installed > \$tmp_file
      mv \$tmp_file \$HOME/.dotfiles-installed

      # Ensure Homebrew-installed tools are in PATH for verification.
      if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"
      fi
      source \$HOME/.bashrc || true

      ./setup --verbose --log verify
    "
  '

echo "==> Plain Ubuntu 24.04 Docker test: PASS"
