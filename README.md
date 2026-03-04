# WSL Dotfiles

Automated WSL developer workstation bootstrap for this team.

`./setup` installs and maintains a consistent local toolchain with:

- Docker (WSL + Windows wrappers)
- Corporate CA updater
- Git baseline config
- Shell baseline config
- Homebrew
- CLI tools (`zoxide`, `fzf`, `ripgrep`, `bat`)
- vfox runtime manager (Node.js, Python, Go, .NET, Java)

## What This Delivers For A Developer

- One command to bootstrap a new WSL distro.
- Predictable dependency order across components.
- Safe re-runs for config installers (idempotent style).
- Built-in verification (`./setup verify`).
- Managed runtime versions from `dev-tools/config/versions.yaml`.
- Fail-fast behavior: install/update stop on first failure and do not rollback previously applied changes.

## Quick Start (WSL)

```bash
git clone <REPO_URL> ~/.dotfiles
cd ~/.dotfiles
./setup install
./setup verify
```

## Daily Commands

```bash
./setup install                 # Install default component set
./setup verify                  # Smoke-test installed components
./setup update                  # Re-run/upgrades installed components
./setup uninstall               # Interactive uninstall
./setup uninstall vfox homebrew # Uninstall specific components
```

Verbose/debug mode:

```bash
./setup --verbose install
./setup --verbose update
./setup --verbose verify
```

## Managed Runtime Versions

Runtime targets are defined in:

- `dev-tools/config/versions.yaml`

Current defaults include:

- Node.js `24`
- Python `3.14.3`
- Go `latest`
- .NET `10`
- Java `21+35-tem`

## Install and Update Behavior

Install flow (`./setup install`) does:

1. Installs required Ubuntu dependencies.
2. Auto-imports already-installed components.
3. Installs components in dependency order.
4. Runs `update-corporate-ca` before `vfox`.
5. Stops immediately on failure (no rollback).

Update flow (`./setup update`) does:

1. Reads tracked installed components from `~/.dotfiles-installed`.
2. Updates managed/imported components in dependency order.
3. Runs `update-corporate-ca` before `vfox`.
4. Stops immediately on failure (no rollback).

## WSL vs Non-WSL

- In WSL: all default components are eligible.
- In raw Ubuntu (non-WSL): WSL-specific components are skipped:
  - `docker` (Windows wrapper integration)
  - `ca-updater` (WSL corporate CA integration path)

## Tracking and Logs

- Installation state file: `~/.dotfiles-installed`
- Log directory (when enabled): `~/.dotfiles-logs/`

## Common Developer Checks

```bash
./setup verify
vfox current
python3 --version
node --version
docker ps
```

## Troubleshooting

Docker permission denied after fresh install:

```bash
newgrp docker
```

Homebrew or vfox not available in current shell:

```bash
source ~/.bashrc
```

vfox download/certificate issues:

```bash
update-corporate-ca --verbose
update-corporate-ca --dry-run
```

## Repository Structure

```text
.dotfiles/
├── setup
├── scripts/
│   ├── install.sh
│   ├── verify.sh
│   ├── update.sh
│   └── uninstall.sh
├── lib/
├── docker-wsl/
├── update-corporate-ca/
├── git/
├── shell/
├── homebrew/
├── cli-tools/
├── dev-tools/
│   └── config/versions.yaml
├── Dockerfile.test
└── test-cycle.sh
```

## License

See `LICENSE`.
