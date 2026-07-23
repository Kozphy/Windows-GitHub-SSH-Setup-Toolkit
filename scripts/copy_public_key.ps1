#Requires -Version 5.1
<#
.SYNOPSIS
  Copy your SSH public key to the clipboard and open GitHub's "new SSH key" page.

.PARAMETER PubKeyPath
  Path to the .pub file. Default: $env:USERPROFILE\.ssh\id_ed25519.pub

.PARAMETER NoBrowser
  Do not open the browser; only copy and print instructions.

.NOTES
  Never prints or copies the private key. Safe for beginners.
#>
param(
    [string]$PubKeyPath = "",
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Continue'

if (-not $PubKeyPath) {
    $PubKeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519.pub"
}

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

Write-Status "INFO" "Prepare public key for GitHub (private key is never touched)"

if (-not (Test-Path -LiteralPath $PubKeyPath)) {
    Write-Status "ERROR" "Public key not found: $PubKeyPath"
    Write-Status "NEXT" 'Create a key pair: ssh-keygen -t ed25519 -C "your_email@example.com"'
    exit 1
}

$pub = (Get-Content -LiteralPath $PubKeyPath -Raw).Trim()
if (-not $pub -or $pub -notmatch '^\s*(ssh-(ed25519|rsa)|ecdsa-sha2-)') {
    Write-Status "ERROR" "File does not look like an OpenSSH public key."
    exit 1
}

# Fingerprint without dumping key material beyond what .pub already is
$fingerprint = ""
try {
    $fingerprint = (& ssh-keygen -lf $PubKeyPath 2>$null | Out-String).Trim()
}
catch { }

try {
    Set-Clipboard -Value $pub
    Write-Status "OK" "Public key copied to clipboard."
}
catch {
    Write-Status "WARN" "Could not copy to clipboard: $($_.Exception.Message)"
    Write-Status "INFO" "Public key path: $PubKeyPath"
    Write-Status "INFO" "Open that .pub file and paste its single line into GitHub."
}

if ($fingerprint) {
    Write-Status "INFO" "Fingerprint: $fingerprint"
}

$newKeyUrl = "https://github.com/settings/ssh/new"
Write-Status "NEXT" "In GitHub: paste the key, give it a title, click Add SSH key."
Write-Status "NEXT" "URL: $newKeyUrl"

if (-not $NoBrowser) {
    try {
        Start-Process $newKeyUrl
        Write-Status "OK" "Opened GitHub new-SSH-key page in your browser."
    }
    catch {
        Write-Status "WARN" "Could not open browser. Visit the URL above manually."
    }
}

Write-Status "NEXT" "After adding the key: .\scripts\test_github_ssh.ps1"
exit 0
