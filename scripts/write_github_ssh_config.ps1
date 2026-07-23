#Requires -Version 5.1
<#
.SYNOPSIS
  Ensure ~/.ssh/config has a github.com Host block pointing at your IdentityFile.

.PARAMETER KeyPath
  Private key path. Default: $env:USERPROFILE\.ssh\id_ed25519

.NOTES
  Idempotent: skips if a github.com Host block already exists.
  Does not overwrite unrelated SSH config entries.
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

$sshDir = Join-Path $env:USERPROFILE ".ssh"
$configPath = Join-Path $sshDir "config"

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Write-Status "ERROR" "Private key not found: $KeyPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir | Out-Null
}

$block = @"
Host github.com
  HostName github.com
  User git
  IdentityFile $KeyPath
  IdentitiesOnly yes
"@

if (Test-Path -LiteralPath $configPath) {
    $existing = Get-Content -LiteralPath $configPath -Raw -ErrorAction SilentlyContinue
    if ($existing -match '(?im)^\s*Host\s+github\.com\b') {
        Write-Status "OK" "SSH config already has a Host github.com block: $configPath"
        Write-Status "INFO" "Not modifying existing Host github.com entry."
        exit 0
    }
    Add-Content -LiteralPath $configPath -Value "`r`n$block`r`n"
    Write-Status "OK" "Appended Host github.com block to $configPath"
}
else {
    Set-Content -LiteralPath $configPath -Value "$block`r`n" -Encoding ASCII
    Write-Status "OK" "Created $configPath with Host github.com block"
}

exit 0
