# WSL Dotfiles

Essential-only dotfiles management system for WSL (Windows Subsystem for Linux) with Docker, Git, Shell, Homebrew, CLI tools (zoxide, fzf, ripgrep, bat), and vfox version manager.

## ✨ Features

- **Transactional Installations**: Automatic rollback on failure
- **Dependency Management**: Components installed in correct order
- **Backup System**: Automatic backup of configs with retention
- **Validation**: Comprehensive smoke tests for all components

## 📦 Components

All components are installed automatically:

### 🐳 Docker WSL Integration
- Docker Engine in WSL Ubuntu (official repository)
- Systemd support for service management
- Windows wrapper commands (`docker.cmd`) in `%USERPROFILE%\bin`
- Automatic Windows PATH update

### 🔒 Corporate CA Certificate Management
- Fetches and installs corporate CA certificates
- Updates system CA trust store
- Silent operation (no warnings on re-install)

### 📦 Git Configuration
- Git aliases: `co`, `st`, `br`, `lg`
- Non-destructive updates via delimited sections

### 🐚 Shell Environment (Bash)
- Enhanced `.bashrc` with history and completion
- Common aliases in `.bash_aliases`

### 🍺 Homebrew Package Manager
- Linuxbrew for WSL
- Integrated into shell environment
- Enables easy package installation

### �️ CLI Tools
- **zoxide**: Smarter `cd` command with frecency-based directory jumping
- **fzf**: Fuzzy finder for files, history, and more
- **ripgrep**: Blazing fast `grep` replacement
- **bat**: `cat` with syntax highlighting and line numbers
- Installed via Homebrew

### �🔧 vfox Version Manager
- Universal version manager for Node.js, Python, Go, .NET, and Java
- Replaces nvm, pyenv, sdkman, and more
- Configured via `dev-tools/config/versions.yaml`

## 📊 Dependency Order

```
docker ────┐
ca-updater ┤ (parallel)
git ───────┤
           └─→ shell ─→ homebrew ─┬─→ cli-tools
                                  └─→ vfox
```

## Prerequisites

- Windows 10 (build 19041+) or Windows 11
- Sudo privileges
- Internet connectivity

### Raw Ubuntu (non-WSL) behavior

`./setup install` also runs on plain Ubuntu. In non-WSL environments, WSL-only components are intentionally skipped:

- `docker` (WSL + Windows wrapper integration)
- `ca-updater` (corporate CA updater integration path)

All other components continue to install and `./setup verify` will report those two as skipped on non-WSL instead of failing.

## 🖥️ Setting Up WSL 2 with Ubuntu

If you don't have WSL 2 installed yet, follow these steps from **PowerShell (Run as Administrator)**:

### 1. Enable WSL and install Ubuntu

```powershell
# Install WSL 2 with Ubuntu as the default distribution (one command does it all)
wsl --install -d Ubuntu
```

This command will:
- Enable the WSL and Virtual Machine Platform features
- Download and install the latest Linux kernel
- Set WSL 2 as the default version
- Download and install the Ubuntu distribution

> **Note:** A reboot may be required after this step. After rebooting, Ubuntu will launch automatically to complete the setup (create user and password).

### 2. Verify the installation

```powershell
# Confirm WSL 2 is running
wsl --list --verbose
```

You should see output like:

```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

### 3. (Optional) Set Ubuntu as default if needed

```powershell
wsl --set-default Ubuntu
```

### 4. Enter your WSL environment

```powershell
wsl
```

You are now inside Ubuntu on WSL 2 and ready to install the dotfiles.

## 🚀 Fresh Distro Bootstrap (PowerShell)

From Windows PowerShell, create a brand-new Ubuntu-based WSL distro, clone this repo, and run install + verify with verbose logging:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wsl\bootstrap-dotfiles.ps1
```

Optional parameters:

```powershell
.\scripts\wsl\bootstrap-dotfiles.ps1 -DistroName rdi-dotfiles-test -Branch dev
```

## Installation

```bash
git clone <REPO_URL> ~/.dotfiles
cd ~/.dotfiles
./setup install
```

The installer will:
1. Install required Ubuntu dependencies
2. Auto-import existing installations
3. Install Docker Engine and Windows wrappers
4. Install CA certificate updater
5. Configure Git with aliases
6. Set up shell environment
7. Install Homebrew
8. Install CLI tools (zoxide, fzf, ripgrep, bat)
9. Refresh corporate CA certificates before vfox downloads
10. Install and configure vfox (Node.js, Python, Go, .NET, Java)

### Options

```bash
./setup                    # Install all components (default)
./setup install            # Same as above
./setup --quiet install    # Minimal output and no file logging
./setup --verbose --log install  # Explicit verbose output + log files
```

## 🔧 Management Commands

### Verify Installation
```bash
./setup verify              # Run smoke tests
./setup --quiet verify      # Minimal output and no file logging
```

### Update Components
```bash
./setup update              # Update all components
./setup --quiet update      # Minimal output and no file logging
```

### Uninstall Components
```bash
./setup uninstall                # Interactive mode
./setup uninstall vfox homebrew  # Specific components
```

## 📝 Configuration

### Component Versions
Edit `config/versions.yaml` in component directories:
- `dev-tools/config/versions.yaml` - Node.js, Python, Java versions

### Installation Tracking
`~/.dotfiles-installed` tracks components with status and versions

### Logs
- `./setup` now defaults to verbose console output and file logging
- `--quiet` disables verbose output and file logging for a single run
- `--verbose` and `--log` can be used explicitly to re-enable either after `--quiet`
- Progress steps are always shown; spinner animation appears only in interactive terminals
- Log files are written to `~/.dotfiles-logs/`
- Homebrew PATH is auto-synced during install/update (manual `eval "$(brew shellenv)"` is not required for the current run)
- `update-corporate-ca` is executed automatically before `vfox` and fails fast if trust/bootstrap fails

## 🔄 Common Workflows

### First-Time Setup
```bash
cd ~/.dotfiles
./setup
source ~/.bashrc
```

### Update Everything
```bash
cd ~/.dotfiles
git pull
./setup update
```

## Usage

### Docker

Docker works from both WSL and Windows:

**From WSL:**
```bash
docker ps
docker run hello-world
```

**From Windows (PowerShell or CMD):**
```powershell
docker ps
docker version
docker-compose version
```

The Windows commands automatically delegate to the Docker daemon running in WSL.

#### Docker Installation Options

You can also run the Docker installer directly with additional options:

```bash
# Install with verbose output
./docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh --verbose

# Specify WSL distro name (if different from current)
./docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh --distro Ubuntu-22.04

# Skip automatic Windows PATH update
./docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh --no-path-update

# Show help
./docker-wsl/install/install-docker-wsl-and-windows-wrapper.sh --help
```

### CLI Tools

```bash
# Smart directory jumping (learns from your cd habits)
z projects        # Jump to most frequent/recent match
zi                # Interactive directory selection with fzf

# Fuzzy finder
fzf               # Interactive file finder
Ctrl+R            # Fuzzy search command history
Ctrl+T            # Fuzzy file picker

# Fast grep
rg "pattern"      # Search files recursively
rg -t py "import" # Search only Python files

# Better cat
bat file.sh       # Syntax-highlighted file viewer
bat --diff a b    # Side-by-side diff
```

### Corporate CA Certificates

The `update-corporate-ca` tool manages corporate TLS inspection certificates:

```bash
# Install/update corporate CA certificates
update-corporate-ca

# Show what would be done without making changes
update-corporate-ca --dry-run

# Show detailed debug information
update-corporate-ca --verbose

# Remove installed corporate CA certificates
update-corporate-ca --cleanup

# Use custom configuration file
update-corporate-ca --config /path/to/custom.conf

# Show all available options
update-corporate-ca --help
```

#### Configuration

**From Windows (PowerShell/CMD):**
```cmd
docker ps
docker-compose version
```

### Homebrew

Install packages easily:
```bash
brew install htop
brew install gh
brew search <package>
```

### vfox Version Manager

Default managed runtime targets include Java `21-tem` (Temurin 21).

```bash
# List available versions
vfox available nodejs
vfox available python

# Install specific version
vfox install nodejs@18.0.0
vfox use nodejs@18.0.0

# Use globally configured versions
vfox list
```

### Corporate CA Certificates

The tool is configured via `/etc/update-corporate-ca.conf`:

```bash
# Hosts to fetch certificates from
HOSTS=(
  "github.com:443"
)

# Regex to filter CA certificates
ALLOWLIST_REGEX="Capgemini|Zscaler"

# Test HTTPS connectivity
TEST_URLS=(
  "https://github.com"
)
```

Run manually:
```bash
update-corporate-ca --verbose
```

## Troubleshooting

### Docker Permission Denied

**Solution:** Start a new shell session (user added to docker group):
```bash
newgrp docker
```

### Homebrew Not in PATH

**Solution:** Source your bashrc:
```bash
source ~/.bashrc
```

### vfox Command Not Found

`setup install` writes `vfox` activation to `~/.bashrc` and also `~/.zshrc` when it exists.

**Solution:** Start a new shell session, or source your profile:
```bash
source ~/.bashrc
# or
source ~/.zshrc
```

### vfox Download Failures (TLS/Certificate)

`setup install` and `setup update` now run `sudo update-corporate-ca` before `vfox`. If this fails:

```bash
update-corporate-ca --verbose
update-corporate-ca --dry-run
```

Then verify VPN/proxy connectivity and `/etc/update-corporate-ca.conf`.

## Repository Structure

```
.dotfiles/
├── setup                         # Main entrypoint
├── scripts/                      # Core scripts
│   ├── install.sh                # Main installer
│   ├── verify.sh                 # Smoke tests
│   ├── update.sh                 # Update components
│   └── uninstall.sh              # Remove components
├── lib/                          # Shared libraries
│   ├── common.sh                 # Utilities
│   ├── dependencies.sh           # DAG management
│   ├── rollback.sh               # Transactions
│   ├── import.sh                 # Auto-import
│   └── actions/                  # Action wrappers for setup
├── docker-wsl/                   # Docker installer
├── update-corporate-ca/          # CA management
├── git/                          # Git config
├── shell/                        # Shell environment
├── homebrew/                     # Homebrew installer
├── cli-tools/                    # CLI tools (zoxide, fzf, ripgrep, bat)
├── dev-tools/                    # vfox installer + versions.yaml
├── Dockerfile.test               # Docker test harness
└── test-cycle.sh                 # Automated test script
```

## License

See [LICENSE](LICENSE) file for details.
