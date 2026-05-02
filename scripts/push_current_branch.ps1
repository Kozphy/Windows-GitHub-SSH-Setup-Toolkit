#Requires -Version 5.1
<#
.SYNOPSIS
  Push the current branch to origin with confirmation (never force push).
#>

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
    Write-Status "ERROR" "Not inside a Git repository."
    exit 1
}

Push-Location $top
try {
    $branch = (git branch --show-current 2>$null).Trim()
    if (-not $branch) {
        Write-Status "ERROR" "Could not determine current branch (detached HEAD or empty)."
        exit 1
    }

    Write-Status "INFO" "Current branch: $branch"

    $cmd = "git push -u origin $branch"
    Write-Status "INFO" "Command to run:"
    Write-Host "  $cmd"
    Write-Host ""

    $answer = Read-Host "Type YES to push (anything else cancels)"
    if ($answer -ne 'YES') {
        Write-Status "INFO" "Cancelled. No push performed."
        exit 0
    }

    git push -u origin $branch
    $exit = $LASTEXITCODE
    if ($exit -eq 0) {
        Write-Status "OK" "Push completed."
        exit 0
    }

    Write-Status "ERROR" "git push failed (exit $exit)."
    Write-Host ""
    Write-Status "INFO" "Common causes (safe fixes only — no force push from this toolkit):"
    Write-Host "  - Permission denied (publickey): SSH key not used by GitHub; fix SSH setup."
    Write-Host "  - Repository not found: wrong remote URL or no access to repo."
    Write-Host "  - non-fast-forward: remote has commits you lack; run git pull --rebase (or merge) first, then push."
    Write-Host "  - upstream already exists: you may use git push (without -u) if upstream is already set."
    exit 1
}
finally {
    Pop-Location
}
