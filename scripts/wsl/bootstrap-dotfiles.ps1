#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$DistroName,
  [string]$RepoUrl = "https://github.com/bhabermann/rdi.dotfiles.git",
  [string]$Branch = "dev"
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host "[bootstrap] $Message"
}

function Invoke-WslCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Distro,
    [Parameter(Mandatory = $true)][string]$Command
  )

  & wsl.exe -d $Distro -u root -- bash --noprofile --norc -c $Command
  if ($LASTEXITCODE -ne 0) {
    throw "WSL command failed in distro '$Distro' (exit code $LASTEXITCODE)."
  }
}

function Get-DistroList {
  $raw = & wsl.exe -l -q 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to query WSL distributions. Is WSL installed?"
  }

  return $raw |
    ForEach-Object { $_ -replace "`0", "" } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }
}

function Test-DistroExists {
  param([string]$Name)
  return (Get-DistroList) -contains $Name
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw "wsl.exe not found. Install WSL first."
}

if ([string]::IsNullOrWhiteSpace($DistroName)) {
  $DistroName = "rdi-dotfiles-ubuntu-{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")
}

if (Test-DistroExists -Name $DistroName) {
  throw "Distro '$DistroName' already exists. Use a different name."
}

$distroList = Get-DistroList
$baseDistro = $distroList | Where-Object { $_ -imatch "^ubuntu" } | Select-Object -First 1

if (-not $baseDistro) {
  Write-Step "No Ubuntu distro found. Installing Ubuntu via WSL..."
  & wsl.exe --install -d Ubuntu
  throw "Ubuntu installation was started. Re-run this script after Ubuntu setup completes."
}

$wslRoot = Join-Path $env:LOCALAPPDATA "WSL"
$installDir = Join-Path $wslRoot $DistroName
$exportTar = Join-Path $env:TEMP ("{0}.tar" -f $DistroName)

New-Item -ItemType Directory -Path $wslRoot -Force | Out-Null

Write-Step "Exporting base distro '$baseDistro'..."
& wsl.exe --export $baseDistro $exportTar
if ($LASTEXITCODE -ne 0) {
  throw "Failed to export base distro '$baseDistro'."
}

try {
  Write-Step "Importing new distro '$DistroName'..."
  & wsl.exe --import $DistroName $installDir $exportTar --version 2
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to import distro '$DistroName'."
  }
}
finally {
  if (Test-Path $exportTar) {
    Remove-Item $exportTar -Force
  }
}

$bootstrapCommand = @'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates sudo bash

TARGET_USER="$(awk -F: '$3 == 1000 { print $1; exit }' /etc/passwd || true)"
if [[ -z "$TARGET_USER" ]]; then
  TARGET_USER="dotfiles"
  useradd -m -s /bin/bash "$TARGET_USER"
fi

echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/99-$TARGET_USER-nopasswd"
chmod 440 "/etc/sudoers.d/99-$TARGET_USER-nopasswd"

sudo -u "$TARGET_USER" -H env NONINTERACTIVE=1 bash --noprofile --norc -c '
set -euo pipefail
rm -rf "$HOME/.dotfiles"
git clone --branch "{0}" --single-branch "{1}" "$HOME/.dotfiles"
cd "$HOME/.dotfiles"
if ./setup --help | grep -q -- "--log"; then
  ./setup --verbose --log install
else
  ./setup --verbose install
fi
./setup --verbose verify
echo "Logs directory: $HOME/.dotfiles-logs"
'
'@ -f $Branch, $RepoUrl

Write-Step "Running install workflow inside '$DistroName'..."
Invoke-WslCommand -Distro $DistroName -Command $bootstrapCommand

Write-Step "Completed successfully."
Write-Host ""
Write-Host "Distro: $DistroName"
Write-Host "Repo:   ~/.dotfiles"
Write-Host "Logs:   ~/.dotfiles-logs"
Write-Host ""
Write-Host "Enter distro: wsl -d $DistroName"
