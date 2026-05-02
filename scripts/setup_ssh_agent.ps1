#Requires -Version 5.1
<#
.SYNOPSIS
  Enable ssh-agent, set Automatic startup, start service, and add a key (does not create keys).

.PARAMETER KeyPath
  Path to private key. Default: $env:USERPROFILE\.ssh\id_ed25519

.NOTES
  Setting service StartupType may require Administrator. Run PowerShell as Administrator if you see errors.
#>
param(
    [string]$KeyPath = ""
)

$ErrorActionPreference = 'Continue'

if (-not $KeyPath) {
    $KeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
}

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

Write-Status "INFO" "Windows ssh-agent setup (does not create new keys)"
Write-Status "INFO" "Key path: $KeyPath"

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Write-Status "ERROR" "Private key file not found. This script does not generate keys."
    Write-Status "NEXT" 'Create a key with: ssh-keygen -t ed25519 -C "your_email@example.com"'
    Write-Status "NEXT" "Then add the .pub key to GitHub, re-run this script to ssh-add the private key."
    exit 1
}

# ssh-agent service
$svc = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Status "ERROR" "Windows service 'ssh-agent' not found. Install OpenSSH Client (optional feature)."
    exit 1
}

try {
    Set-Service -Name "ssh-agent" -StartupType Automatic -ErrorAction Stop
    Write-Status "OK" "ssh-agent StartupType set to Automatic."
}
catch {
    Write-Status "WARN" "Could not set ssh-agent to Automatic: $($_.Exception.Message)"
    Write-Status "INFO" "Try: Run PowerShell as Administrator, or run: Set-Service -Name ssh-agent -StartupType Automatic"
}

try {
    $svc = Get-Service -Name "ssh-agent"
    if ($svc.Status -eq 'Running') {
        Write-Status "OK" "ssh-agent is already running."
    }
    else {
        Start-Service -Name "ssh-agent" -ErrorAction Stop
        Write-Status "OK" "ssh-agent service started."
    }
}
catch {
    Write-Status "ERROR" "Could not start ssh-agent: $($_.Exception.Message)"
    exit 1
}

# ssh-add
Write-Status "INFO" "Running: ssh-add for your key (passphrase prompt may appear)"
try {
    & ssh-add $KeyPath
    if ($LASTEXITCODE -ne 0) {
        Write-Status "ERROR" "ssh-add returned failure (exit $LASTEXITCODE)."
        exit 1
    }
    Write-Status "OK" "Key added to ssh-agent."
}
catch {
    Write-Status "ERROR" "ssh-add failed: $($_.Exception.Message)"
    exit 1
}

Write-Status "NEXT" "Test GitHub: .\scripts\test_github_ssh.ps1"
exit 0
