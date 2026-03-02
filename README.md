# WSL Dotfiles

A modular dotfiles management system for WSL (Windows Subsystem for Linux) with Docker integration, corporate CA certificate management, and optional development tools.

## ✨ Features

### Core System
- **Transactional Installations**: Automatic rollback on failure with cascading dependency support
- **Dependency Management**: DAG-based component dependencies with cycle detection
- **Smart Import**: Auto-detects existing installations and manages them going forward
- **Backup System**: Automatic backup of configs with 10-backup retention
- **Validation**: Comprehensive smoke tests for all components

### 🐳 Docker WSL Integration (Essential)
- Installs Docker Engine natively in WSL Ubuntu using the official Docker repository
- Enables systemd support for proper Docker service management
- Creates native Windows wrapper commands (`docker.cmd`, `docker-compose.cmd`) in `%USERPROFILE%\bin`
- Automatically updates Windows PATH for seamless command-line access
- Allows running Docker from Windows terminal while the daemon runs in WSL

### 🔒 Corporate CA Certificate Management (Essential)
- Fetches and installs corporate TLS inspection CA certificates (e.g., Zscaler, Capgemini)
- Validates certificates before installation (must be CA:TRUE and match allowlist)
- Updates system CA trust store for HTTPS connectivity
- Tests connectivity to configured URLs after installation
- Supports cleanup, dry-run, and verbose modes
- Logs all operations to `~/.cache/update-corporate-ca.log`

### 📦 Git Configuration (Essential)
- Git aliases: `co` (checkout), `st` (status), `br` (branch), `lg` (log graph)
- Preserves existing `.gitconfig` via delimited sections
- Non-destructive updates

### 🐚 Shell Environment (Essential)
- Enhanced `.bashrc` with history settings and tab completion
- Common aliases in `.bash_aliases`
- Preserves existing configurations

## 🎯 Optional Components

### vfox - Version Manager
- Universal version manager for Node.js, Python, and Java
- Replaces nvm, pyenv, and sdkman with a single tool
- Configures specific versions from `versions.yaml`:
  - Node.js: 20.11.0
  - Python: 3.12.1
  - Java: latest
- **Dependency**: Requires `shell` component

### cloud - Cloud Provider CLIs
- **AWS CLI** (latest): Amazon Web Services command-line interface
- **Azure CLI** (latest): Microsoft Azure command-line interface
- **Google Cloud SDK** (latest): Google Cloud Platform (for AI integration)
- Shell completions and helpful aliases
- Includes `gcloud ai` for Vertex AI and other Google AI services

## 📊 Component Dependency Graph

```
Essential (always installed):
  docker ━━━━━━━━━┓
  corporate-ca ━━━┫  (installed first)
  git ━━━━━━━━━━━┫
  shell ━━━━━━━━━┛

Optional (--interactive or --non-interactive):
  shell ──→ vfox
  
  cloud (standalone - includes Google Cloud for AI)
```

## Prerequisites

- **WSL 2** with **Ubuntu** distribution
- Windows 10/11 with WSL feature enabled
- Sudo privileges in WSL
- Internet connectivity for package downloads
- `jq` (auto-installed if missing)

## Installation

Clone this repository to your WSL home directory and run the installer:

```bash
git clone <REPO_URL> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

### Installation Modes

#### Interactive Mode (Default)
Prompts for each optional component:
```bash
./install.sh
# or explicitly
./install.sh --interactive
```

#### Essentials Only
Installs only essential components (Docker, CA, Git, Shell):
```bash
./install.sh --essentials-only
```

#### Install All (Non-Interactive)
Installs all components automatically without prompting:
```bash
./install.sh --all
```

#### With Logging
Enable detailed logging to `~/.dotfiles-logs/`:
```bash
./install.sh --interactive --log --verbose
```

### What Gets Installed

The installer will:
1. Auto-import any existing installations
2. Detect and prevent dependency cycles
3. Enable systemd in WSL (if needed)
4. Install Docker Engine and Windows wrappers
5. Install corporate CA management tool
6. Set up Git configuration with aliases
7. Configure shell environment
8. Install selected optional components
9. Backup existing configs (10-backup retention)
10. Validate with smoke tests
11. Track in `~/.dotfiles-installed`

## 🔧 Management Commands

### Verify Installation
```bash
./verify.sh              # Run smoke tests
./verify.sh --verbose    # Detailed output
```

### Update Components
```bash
./update.sh             # Update all components
./update.sh --log       # With logging
```

### Uninstall Components
```bash
./uninstall.sh                    # Interactive
./uninstall.sh vfox cloud         # Specific components
./uninstall.sh --force kubernetes # Bypass dependency checks
```

## 📝 Configuration Files

### Component Versions
Edit `config/versions.yaml` in each component directory to customize versions.

### Delimited Sections
Configs use delimited sections for non-destructive updates:
```bash
# >>> dotfiles:marker >>>
# Managed content
# <<< dotfiles:marker <<<
```

### Installation Tracking
`~/.dotfiles-installed` tracks all components with status (`ok`/`imported`/`failed`), versions, and backup directories.

## 🔄 Common Workflows

### First-Time Setup
```bash
cd ~/.dotfiles
./install.sh --interactive
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

After installation, Docker commands work from both WSL and Windows terminals:

**From WSL:**
```bash
docker ps
docker run hello-world
docker compose version
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

The tool is configured via `/etc/update-corporate-ca.conf`:

```bash
# Hosts to fetch certificates from
HOSTS=(
  "github.com:443"
  "sharepoint.example.com:443"
  "wiki.example.com:443"
)

# Regex to filter CA certificates by subject
ALLOWLIST_REGEX="Capgemini|Zscaler"

# URLs to test HTTPS connectivity after installation
TEST_URLS=(
  "https://github.com"
  "https://www.google.com"
)

# Connection timeouts (in seconds)
CURL_CONNECT_TIMEOUT=8
CURL_MAX_TIME=20
```

## Troubleshooting

### Systemd Not Enabled

**Problem:** Docker installer exits and asks you to restart WSL.

**Solution:** The installer automatically configures systemd in `/etc/wsl.conf`. After the installer exits:
1. Open PowerShell or CMD on Windows
2. Run: `wsl --shutdown`
3. Reopen your WSL distribution
4. Run the installer again: `cd ~/.dotfiles && ./install.sh`

### Docker Permission Denied

**Problem:** `docker: permission denied while trying to connect to the Docker daemon socket`

**Solution:** The installer adds your user to the `docker` group, but you need to start a new shell session:
```bash
# Exit your current WSL session and reopen it, OR:
newgrp docker
```

### Windows Commands Not Found

**Problem:** `docker` or `docker-compose` commands not found in Windows terminal.

**Solution:**
1. Verify wrappers were created: Check if `%USERPROFILE%\bin\docker.cmd` exists
2. Add to PATH manually:
   - Open "Environment Variables" in Windows settings
   - Add `%USERPROFILE%\bin` to your User PATH
   - Open a **new** terminal window (restart required for PATH changes)

### Corporate Certificates Not Working

**Problem:** HTTPS requests still fail after running `update-corporate-ca`.

**Solution:**
1. Run with verbose mode to see detailed logs:
   ```bash
   update-corporate-ca --verbose
   ```
2. Check the log file for errors:
   ```bash
   cat ~/.cache/update-corporate-ca.log
   ```
3. Verify certificates were installed:
   ```bash
   ls -la /usr/local/share/ca-certificates/corporate-proxy-ca-*.crt
   ```
4. Manually update CA certificates:
   ```bash
   sudo update-ca-certificates
   ```

### Script Permission Denied

**Problem:** `./install.sh: Permission denied`

**Solution:** Git should preserve executable permissions when you clone. If not:
```bash
chmod +x install.sh
chmod +x docker-wsl/install/*.sh
chmod +x update-corporate-ca/install/*.sh
chmod +x update-corporate-ca/bin/*
```

### Running from Windows Filesystem (/mnt/c)

**Problem:** Warning about running from Windows-mounted path.

**Solution:** For best performance and compatibility, clone to the Linux filesystem:
```bash
# Move from /mnt/c/Users/... to Linux filesystem
cd ~
git clone <REPO_URL> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Repository Structure

```
.dotfiles/
├── install.sh                                    # Main installer (orchestrates all installations)
├── docker-wsl/
│   └── install/
│       └── install-docker-wsl-and-windows-wrapper.sh  # Docker + Windows wrapper installer
└── update-corporate-ca/
    ├── bin/
    │   └── update-corporate-ca                   # Corporate CA management tool
    ├── config/
    │   └── update-corporate-ca.conf              # Default configuration
    └── install/
        └── install-update-corporate-ca.sh        # Corporate CA installer
```

## License

See [LICENSE](LICENSE) file for details.
