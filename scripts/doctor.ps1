#Requires -Version 5.1
<#
.SYNOPSIS
  One-command read-only health check: same checks as diagnose_ssh.ps1, compact output only.
#>

$ErrorActionPreference = 'Continue'
& "$PSScriptRoot\diagnose_ssh.ps1" -Doctor
# diagnose_ssh.ps1 exits the process with the correct exit code when invoked this way
