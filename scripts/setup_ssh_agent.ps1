#Requires -Version 5.1
<#
.SYNOPSIS
  Enable ssh-agent (with UAC if needed), start it, and ssh-add a local key.

.PARAMETER KeyPath
  Path to private key. Default: $env:USERPROFILE\.ssh\id_ed25519

.PARAMETER SkipElevation
  Do not prompt for UAC; fail with clear NEXT steps if admin is required.

.NOTES
  Does not create SSH keys. Does not print private key contents.
#>
param(
    [string]$KeyPath = '',
    [switch]$SkipElevation
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\common.ps1"

if (-not $KeyPath) {
    $KeyPath = Get-DefaultSshKeyPath
}

Write-Status 'INFO' 'Windows ssh-agent setup (does not create new keys)'
Write-Status 'INFO' "Key path: $KeyPath"

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Write-Status 'ERROR' 'Private key file not found. This script does not generate keys.'
    Write-Status 'NEXT' 'Create a key with: ssh-keygen -t ed25519 -C "your_email@example.com"'
    Write-Status 'NEXT' 'Add the matching .pub file in GitHub -> Settings -> SSH and GPG keys'
    Write-Status 'NEXT' 'Then re-run this script to ssh-add the private key.'
    exit 1
}

$enableScript = Join-Path $PSScriptRoot 'enable_ssh_agent_service.ps1'
$svc = Get-SshAgentService
if (-not $svc) {
    Write-Status 'ERROR' "Windows service 'ssh-agent' not found. Install OpenSSH Client."
    exit 1
}

$agentReady = Test-SshAgentRunning
if (-not $agentReady) {
    Write-Status 'INFO' "ssh-agent is not running (Status=$($svc.Status), StartType=$($svc.StartType))."

    if (Test-IsAdministrator) {
        if (-not (Enable-SshAgentService)) {
            exit 1
        }
    }
    elseif ($SkipElevation) {
        Write-Status 'ERROR' 'ssh-agent needs Administrator to enable/start, and -SkipElevation was set.'
        Write-Status 'NEXT' 'Run PowerShell as Administrator:'
        Write-Status 'NEXT' '  Set-Service -Name ssh-agent -StartupType Automatic'
        Write-Status 'NEXT' '  Start-Service ssh-agent'
        Write-Status 'NEXT' 'Then re-run this script (no admin needed for ssh-add once the service runs).'
        exit 1
    }
    else {
        $ok = Request-ElevatedSshAgentEnable -EnableScriptPath $enableScript
        if (-not $ok) {
            Write-Status 'ERROR' 'Failed to enable/start ssh-agent.'
            Write-Status 'NEXT' 'Manual admin steps:'
            Write-Status 'NEXT' '  Set-Service -Name ssh-agent -StartupType Automatic'
            Write-Status 'NEXT' '  Start-Service ssh-agent'
            exit 1
        }
        Write-Status 'OK' 'ssh-agent is running.'
    }
}
else {
    Write-Status 'OK' 'ssh-agent is already running.'
    # Best-effort: ensure Automatic so it survives reboot (may need admin if Disabled was already fixed)
    if ($svc.StartType -ne 'Automatic') {
        try {
            Set-Service -Name 'ssh-agent' -StartupType Automatic -ErrorAction Stop
            Write-Status 'OK' 'ssh-agent StartupType set to Automatic.'
        }
        catch {
            Write-Status 'WARN' "Could not set StartupType to Automatic: $($_.Exception.Message)"
            Write-Status 'NEXT' 'As Administrator: Set-Service -Name ssh-agent -StartupType Automatic'
        }
    }
}

if (-not (Test-CommandExists 'ssh-add')) {
    Write-Status 'ERROR' 'ssh-add not found on PATH. Install OpenSSH Client.'
    exit 1
}

Write-Status 'INFO' 'Running: ssh-add (passphrase prompt may appear in this window)'
try {
    & ssh-add $KeyPath
    if ($LASTEXITCODE -ne 0) {
        Write-Status 'ERROR' "ssh-add returned failure (exit $LASTEXITCODE)."
        Write-Status 'NEXT' 'Confirm the key path and passphrase. Then: ssh-add -l'
        exit 1
    }
    Write-Status 'OK' 'Key added to ssh-agent.'
}
catch {
    Write-Status 'ERROR' "ssh-add failed: $($_.Exception.Message)"
    exit 1
}

Write-Status 'INFO' 'Loaded identities (fingerprints only):'
& ssh-add -l 2>&1 | ForEach-Object { Write-Host $_ }

Write-Status 'NEXT' 'Verify GitHub: .\scripts\test_github_ssh.ps1'
Write-Status 'NEXT' 'Or run the full flow: .\scripts\complete_ssh_setup.ps1'
exit 0
