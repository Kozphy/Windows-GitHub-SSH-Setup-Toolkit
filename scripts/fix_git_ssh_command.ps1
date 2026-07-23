#Requires -Version 5.1
<#
.SYNOPSIS
  Point Git at Windows OpenSSH so pushes use the Windows ssh-agent.

.PARAMETER Scope
  local (default, current repo) or global.

.PARAMETER Yes
  Apply without typing YES (for automation). Still prints the exact change.

.NOTES
  Git for Windows often uses its own ssh.exe, which may not see keys loaded in
  the Windows OpenSSH Authentication Agent. Symptom: ssh -T works, but git push
  fails with Permission denied / read_passphrase can't open /dev/tty.
#>
param(
    [ValidateSet('local', 'global')]
    [string]$Scope = 'local',
    [switch]$Yes
)

$ErrorActionPreference = 'Continue'

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

$winSsh = Join-Path $env:SystemRoot "System32\OpenSSH\ssh.exe"
if (-not (Test-Path -LiteralPath $winSsh)) {
    Write-Status "ERROR" "Windows OpenSSH not found at $winSsh"
    Write-Status "NEXT" "Install OpenSSH Client (Windows Optional Feature), then re-run."
    exit 1
}

# Forward slashes avoid Git Bash path mangling (C:\... -> C:Windows...)
$configValue = ($winSsh -replace '\\', '/')

Write-Status "INFO" "Will set core.sshCommand ($Scope) to: $configValue"
$current = ""
try {
    if ($Scope -eq 'global') {
        $current = (git config --global --get core.sshCommand 2>$null)
    }
    else {
        $top = (git rev-parse --show-toplevel 2>$null)
        if (-not $top) {
            Write-Status "ERROR" "Not inside a Git repository. cd to your project or use -Scope global."
            exit 1
        }
        $current = (git config --local --get core.sshCommand 2>$null)
    }
}
catch { }

if ($current) {
    Write-Status "INFO" "Current core.sshCommand: $current"
    if ($current -eq $configValue) {
        Write-Status "OK" "Already configured. No change needed."
        exit 0
    }
}

if (-not $Yes) {
    Write-Host ""
    Write-Status "INFO" "Type YES to apply this Git config change (nothing else)."
    $answer = Read-Host "Confirm"
    if ($answer -ne 'YES') {
        Write-Status "INFO" "Cancelled. No changes made."
        exit 0
    }
}

try {
    if ($Scope -eq 'global') {
        git config --global core.sshCommand $configValue
    }
    else {
        git config --local core.sshCommand $configValue
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Status "ERROR" "git config failed (exit $LASTEXITCODE)."
        exit 1
    }
    Write-Status "OK" "core.sshCommand set ($Scope)."
    Write-Status "NEXT" "Retry: git push"
    Write-Status "NEXT" "Verify: .\scripts\test_github_ssh.ps1"
    exit 0
}
catch {
    Write-Status "ERROR" $_.Exception.Message
    exit 1
}
