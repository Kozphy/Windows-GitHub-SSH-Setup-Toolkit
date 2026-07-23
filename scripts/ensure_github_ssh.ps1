#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot: enable ssh-agent, load key, test GitHub; if still denied, help add the public key.

.PARAMETER KeyPath
  Private key path. Default: $env:USERPROFILE\.ssh\id_ed25519

.PARAMETER SkipElevate
  Pass through to setup_ssh_agent.ps1 (no UAC).

.PARAMETER NoBrowser
  Do not open GitHub in the browser when a public key must be added.
#>
param(
    [string]$KeyPath = "",
    [switch]$SkipElevate,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Continue'

if (-not $KeyPath) {
    $KeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
}

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

function Test-GitHubAuth {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "ssh"
    $psi.Arguments = "-T -o BatchMode=yes -o ConnectTimeout=15 git@github.com"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    if (-not $p.WaitForExit(20000)) {
        try { $p.Kill() } catch { }
        return @{ Ok = $false; Text = "timeout"; PermissionDenied = $false }
    }
    $text = ($p.StandardOutput.ReadToEnd() + "`n" + $p.StandardError.ReadToEnd())
    return @{
        Ok = ($text -match "successfully authenticated")
        Text = $text
        PermissionDenied = ($text -match "Permission denied")
    }
}

function Test-GitHubAuthWithIdentity {
    param([string]$Identity)
    if (-not (Test-Path -LiteralPath $Identity)) {
        return @{ Ok = $false; Text = "missing key"; PermissionDenied = $false }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "ssh"
    $psi.Arguments = "-T -o BatchMode=yes -o IdentitiesOnly=yes -i `"$Identity`" -o ConnectTimeout=15 git@github.com"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    if (-not $p.WaitForExit(20000)) {
        try { $p.Kill() } catch { }
        return @{ Ok = $false; Text = "timeout"; PermissionDenied = $false }
    }
    $text = ($p.StandardOutput.ReadToEnd() + "`n" + $p.StandardError.ReadToEnd())
    return @{
        Ok = ($text -match "successfully authenticated")
        Text = $text
        PermissionDenied = ($text -match "Permission denied")
    }
}

Write-Host ""
Write-Status "INFO" "ensure_github_ssh: diagnose -> agent -> verify -> pubkey help"
Write-Host ""

# Step 1: agent + ssh-add
$setupArgs = @{ KeyPath = $KeyPath }
if ($SkipElevate) { $setupArgs.SkipElevate = $true }
& "$PSScriptRoot\setup_ssh_agent.ps1" @setupArgs
$setupExit = $LASTEXITCODE
if ($setupExit -ne 0) {
    Write-Status "WARN" "setup_ssh_agent exited $setupExit. Continuing with direct IdentityFile test..."
}

# Step 2: default auth test
Write-Host ""
Write-Status "INFO" "Testing GitHub SSH (default / agent)..."
$auth = Test-GitHubAuth
if ($auth.Ok) {
    Write-Status "OK" "GitHub SSH authentication succeeded."
    Write-Status "NEXT" "Push from your project: git push -u origin <branch>"
    Write-Status "NEXT" "Or: .\scripts\push_current_branch.ps1 (from your project folder)"
    exit 0
}

# Step 3: direct key file test (isolates agent vs GitHub registration)
Write-Status "INFO" "Testing GitHub SSH with explicit IdentityFile (agent-independent)..."
$direct = Test-GitHubAuthWithIdentity -Identity $KeyPath
if ($direct.Ok) {
    Write-Status "OK" "GitHub accepts this key when offered directly."
    Write-Status "WARN" "Default ssh still failed - agent/config issue. Re-run setup_ssh_agent.ps1 or add ~/.ssh/config Host github.com IdentityFile."
    & "$PSScriptRoot\write_github_ssh_config.ps1" -KeyPath $KeyPath
    $auth2 = Test-GitHubAuth
    if ($auth2.Ok) {
        Write-Status "OK" "GitHub SSH works after writing SSH config."
        exit 0
    }
    Write-Status "WARN" "Still failing after config write. Review ssh -vT git@github.com"
    exit 1
}

if ($direct.PermissionDenied -or $auth.PermissionDenied) {
    Write-Status "ERROR" "Permission denied (publickey): GitHub does not recognize this key yet."
    Write-Status "INFO" "Your local private key exists, but the matching public key must be added to your GitHub account."
    Write-Host ""
    $copyArgs = @{}
    if ($NoBrowser) { $copyArgs.NoBrowser = $true }
    $pub = "$KeyPath.pub"
    if (-not ($KeyPath -like "*.pub")) {
        # KeyPath is private; pub is sibling .pub
        if (Test-Path -LiteralPath ($KeyPath + ".pub")) { $pub = $KeyPath + ".pub" }
        elseif (Test-Path -LiteralPath ((Join-Path (Split-Path $KeyPath) ((Split-Path $KeyPath -Leaf) + ".pub")))) {
            $pub = Join-Path (Split-Path $KeyPath) ((Split-Path $KeyPath -Leaf) + ".pub")
        }
    }
    if (Test-Path -LiteralPath $pub) {
        $copyArgs.PubKeyPath = $pub
    }
    & "$PSScriptRoot\copy_public_key.ps1" @copyArgs
    Write-Host ""
    Write-Status "NEXT" "After you click Add SSH key on GitHub, re-run: .\scripts\test_github_ssh.ps1"
    Write-Status "NEXT" "Then push your branch from the project repo."
    exit 2
}

Write-Status "WARN" "Could not confirm GitHub auth. Output snippet:"
Write-Host (($auth.Text -split "`n" | Select-Object -First 6) -join "`n")
Write-Status "NEXT" "Run: .\scripts\diagnose_ssh.ps1"
exit 1
