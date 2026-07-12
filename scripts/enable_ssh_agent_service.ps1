#Requires -Version 5.1
<#
.SYNOPSIS
  Enable Windows ssh-agent (StartupType Automatic) and start the service.

.PARAMETER Elevated
  Internal: indicates this process already has Administrator rights (used after UAC).

.NOTES
  Enabling a Disabled ssh-agent service requires Administrator.
  This script does not create keys and does not run ssh-add.
#>
param(
    [switch]$Elevated
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\common.ps1"

Write-Status 'INFO' 'Enable/start Windows OpenSSH Authentication Agent (ssh-agent)'

if (-not (Get-SshAgentService)) {
    Write-Status 'ERROR' "Service 'ssh-agent' not found. Install OpenSSH Client."
    exit 1
}

$svc = Get-SshAgentService
Write-Status 'INFO' "Current status: $($svc.Status); StartType: $($svc.StartType)"

$needsAdmin = ($svc.StartType -eq 'Disabled') -or ($svc.Status -ne 'Running')
$isAdmin = Test-IsAdministrator

if ($needsAdmin -and -not $isAdmin) {
    if ($Elevated) {
        Write-Status 'ERROR' 'Process was launched with -Elevated but is not Administrator. Elevation cancelled or failed.'
        exit 1
    }
    Write-Status 'WARN' 'Current session is not elevated; ssh-agent enable/start usually needs Administrator.'
    $ok = Request-ElevatedSshAgentEnable -EnableScriptPath $PSCommandPath
    if ($ok) {
        Write-Status 'OK' 'ssh-agent is running after elevation.'
        exit 0
    }
    Write-Status 'ERROR' 'Could not enable/start ssh-agent without Administrator.'
    Write-Status 'NEXT' 'Right-click PowerShell -> Run as administrator, then:'
    Write-Status 'NEXT' '  Set-Service -Name ssh-agent -StartupType Automatic'
    Write-Status 'NEXT' '  Start-Service ssh-agent'
    Write-Status 'NEXT' 'Or re-run: .\scripts\enable_ssh_agent_service.ps1'
    exit 1
}

if (Enable-SshAgentService) {
    $svc = Get-SshAgentService
    Write-Status 'OK' "ssh-agent ready (Status=$($svc.Status), StartType=$($svc.StartType))."
    exit 0
}

exit 1
