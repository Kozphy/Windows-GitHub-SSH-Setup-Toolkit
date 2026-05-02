#Requires -Version 5.1
<#
.SYNOPSIS
  Set origin (or another remote) to GitHub SSH URL after confirmation.

.PARAMETER RepoOwner
  GitHub owner or organization name.

.PARAMETER RepoName
  Repository name.

.PARAMETER RemoteName
  Remote to update (default: origin).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoOwner,

    [Parameter(Mandatory = $true)]
    [string]$RepoName,

    [string]$RemoteName = "origin"
)

$ErrorActionPreference = 'Continue'

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Status "ERROR" "git is not installed or not on PATH."
    exit 1
}

$top = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $top) {
    Write-Status "ERROR" "Not inside a Git repository. cd into your repo first."
    exit 1
}

Push-Location $top
try {
    $currentUrl = git remote get-url $RemoteName 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Status "ERROR" "Remote '$RemoteName' does not exist. Add it first: git remote add $RemoteName <url>"
        exit 1
    }

    $newUrl = "git@github.com:${RepoOwner}/${RepoName}.git"

    Write-Status "INFO" "Current remote '$RemoteName' URL:"
    Write-Host "  $currentUrl"
    Write-Host ""
    Write-Status "INFO" "New SSH URL will be:"
    Write-Host "  $newUrl"
    Write-Host ""

    $answer = Read-Host "Type YES to change remote URL (anything else cancels)"
    if ($answer -ne 'YES') {
        Write-Status "INFO" "Cancelled. No changes made."
        exit 0
    }

    git remote set-url $RemoteName $newUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Status "ERROR" "git remote set-url failed."
        exit 1
    }

    Write-Status "OK" "Remote updated."
    Write-Host ""
    git remote -v
    Write-Host ""
    Write-Status "INFO" "This script does not push. When ready: git push -u $RemoteName $(git branch --show-current)"
}
finally {
    Pop-Location
}

exit 0
