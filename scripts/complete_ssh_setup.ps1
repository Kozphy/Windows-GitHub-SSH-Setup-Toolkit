#Requires -Version 5.1
<#
.SYNOPSIS
  End-to-end GitHub SSH setup on Windows:
  1) Enable/start ssh-agent (UAC if needed)
  2) ssh-add default (or -KeyPath) key
  3) ssh -T git@github.com

.PARAMETER KeyPath
  Path to private key. Default: $env:USERPROFILE\.ssh\id_ed25519

.PARAMETER SkipElevation
  Do not prompt for UAC if admin is required for the service.

.PARAMETER SkipTest
  Stop after ssh-add; do not run GitHub SSH test.

.NOTES
  Safe-by-default: does not create keys, does not rewrite remotes, does not push.
#>
param(
    [string]$KeyPath = '',
    [switch]$SkipElevation,
    [switch]$SkipTest
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\common.ps1"

if (-not $KeyPath) {
    $KeyPath = Get-DefaultSshKeyPath
}

Write-Host ''
Write-Host '========== COMPLETE SSH SETUP =========='
Write-Status 'INFO' 'This flow: enable ssh-agent -> ssh-add -> ssh -T git@github.com'
Write-Status 'INFO' 'No remote URL changes. No git push. No key generation.'
Write-Host ''

# Step 1–2: agent + key
$setupArgs = @()
if ($KeyPath) { $setupArgs += @('-KeyPath', $KeyPath) }
if ($SkipElevation) { $setupArgs += '-SkipElevation' }

Write-Status 'INFO' 'Step 1/2: setup_ssh_agent.ps1'
& "$PSScriptRoot\setup_ssh_agent.ps1" @setupArgs
$setupExit = $LASTEXITCODE
if ($setupExit -ne 0) {
    Write-Status 'ERROR' "setup_ssh_agent.ps1 failed (exit $setupExit). Aborting before GitHub test."
    exit $setupExit
}

if ($SkipTest) {
    Write-Status 'OK' 'Setup finished (-SkipTest). Run .\scripts\test_github_ssh.ps1 when ready.'
    exit 0
}

Write-Host ''
Write-Status 'INFO' 'Step 2/2: test_github_ssh.ps1'
& "$PSScriptRoot\test_github_ssh.ps1"
$testExit = $LASTEXITCODE

Write-Host ''
Write-Host '========== SUMMARY =========='
if ($testExit -eq 0) {
    Write-Status 'OK' 'Complete SSH setup succeeded (agent + key + GitHub auth).'
    Write-Status 'NEXT' 'Use SSH remotes like git@github.com:OWNER/REPO.git and git push.'
    exit 0
}

Write-Status 'WARN' 'Agent/key setup may be OK, but GitHub SSH test failed.'
Write-Status 'NEXT' 'Confirm your public key (.pub) is added on GitHub -> Settings -> SSH and GPG keys'
Write-Status 'NEXT' 'Public key path (share/upload .pub only):'
Write-Host "  $KeyPath.pub"
Write-Status 'NEXT' 'Re-test: .\scripts\test_github_ssh.ps1'
Write-Status 'NEXT' 'Or use HTTPS remotes temporarily if gh/PAT is already configured.'
exit $testExit
