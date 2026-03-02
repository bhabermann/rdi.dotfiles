# WSL Dotfiles

Essential-only dotfiles management system for WSL (Windows Subsystem for Linux) with Docker, Git, Shell, Homebrew, and vfox version manager.

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

### 🔧 vfox Version Manager
- Universal version manager for Node.js, Python, Java
- Replaces nvm, pyenv, sdkman
- Configured versions:
  - Node.js: 20.11.0
  - Python: 3.12.1
  - Java: latest

## 📊 Dependency Order

```
docker ────┐
ca-updater ┤ (parallel)
git ───────┤
shell ─────┴─→ homebrew ─→ vfox
```

## Prerequisites

- WSL 2 with Ubuntu
- Windows 10/11
- Sudo privileges
- Internet connectivity

## Installation

```bash
git clone <REPO_URL> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The installer will:
1. Auto-import existing installations
2. Install Docker Engine and Windows wrappers
3. Install CA certificate updater
4. Configure Git with aliases
5. Set up shell environment
6. Install Homebrew
7. Install and configure vfox
8. Backup existing configs
9. Validate with smoke tests

### Options

```bash
./install.sh            # Standard installation
./install.sh --verbose  # Detailed output
```

## 🔧 Management Commands

### Verify Installation
```bash
./verify.sh              # Run smoke tests
./verify.sh --verbose    # Detailed output
```

### Update Components
```bash
./update.sh              # Update all components
```

### Uninstall Components
```bash
./uninstall.sh                # Interactive mode
./uninstall.sh vfox homebrew  # Specific components
```

## 📝 Configuration

### Component Versions
Edit `config/versions.yaml` in component directories:
- `dev-tools/config/versions.yaml` - Node.js, Python, Java versions

### Installation Tracking
`~/.dotfiles-installed` tracks components with status and versions

## 🔄 Common Workflows

### First-Time Setup
```bash
cd ~/.dotfiles
./install.sh
./verify.sh
source ~/.bashrc
```

### Update Everything
```bash
cd ~/.dotfiles
git pull
./update.sh
./verify.sh
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

**Solution:** Restart shell or source bashrc:
```bash
source ~/.bashrc
```

## Repository Structure

```
.dotfiles/
├── install.sh                    # Main installer
├── verify.sh                     # Smoke tests
├── update.sh                     # Update components
├── uninstall.sh                  # Remove components
├── lib/                          # Shared libraries
│   ├── common.sh                 # Utilities
│   ├── dependencies.sh           # DAG management
│   ├── rollback.sh               # Transactions
│   └── import.sh                 # Auto-import
├── docker-wsl/                   # Docker installer
├── update-corporate-ca/          # CA management
├── git/                          # Git config
├── shell/                        # Shell environment
├── homebrew/                     # Homebrew installer
└── dev-tools/                    # vfox installer
```

## License

See [LICENSE](LICENSE) file for details.
