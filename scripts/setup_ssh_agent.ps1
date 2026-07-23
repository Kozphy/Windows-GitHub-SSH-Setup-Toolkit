#Requires -Version 5.1
<#
.SYNOPSIS
  Enable ssh-agent, set Automatic startup, start service, and add a key (does not create keys).

.PARAMETER KeyPath
  Path to private key. Default: $env:USERPROFILE\.ssh\id_ed25519

.PARAMETER Elevated
  Internal: set when re-launched via UAC for service configuration.

.PARAMETER SkipElevate
  Do not prompt for Administrator elevation if service start fails.

.NOTES
  Setting service StartupType / starting a Disabled service requires Administrator.
  This script can re-launch itself elevated (UAC prompt) when needed.
#>
param(
    [string]$KeyPath = "",
    [switch]$Elevated,
    [switch]$SkipElevate
)

$ErrorActionPreference = 'Continue'

if (-not $KeyPath) {
    $KeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
}

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedSelf {
    param([string]$Key)
    $ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $PSCommandPath,
        "-Elevated",
        "-KeyPath", $Key
    )
    Write-Status "INFO" "Requesting Administrator elevation (UAC) to enable/start ssh-agent..."
    try {
        $p = Start-Process -FilePath $ps -Verb RunAs -ArgumentList $args -Wait -PassThru
        return $p.ExitCode
    }
    catch {
        Write-Status "ERROR" "Elevation cancelled or failed: $($_.Exception.Message)"
        return 1
    }
}

Write-Status "INFO" "Windows ssh-agent setup (does not create new keys)"
Write-Status "INFO" "Key path: $KeyPath"

if (-not (Test-Path -LiteralPath $KeyPath)) {
    Write-Status "ERROR" "Private key file not found. This script does not generate keys."
    Write-Status "NEXT" 'Create a key with: ssh-keygen -t ed25519 -C "your_email@example.com"'
    Write-Status "NEXT" "Then add the .pub key to GitHub, re-run this script to ssh-add the private key."
    exit 1
}

$svc = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Status "ERROR" "Windows service 'ssh-agent' not found. Install OpenSSH Client (optional feature)."
    exit 1
}

$needServiceWork = ($svc.StartType -eq 'Disabled') -or ($svc.Status -ne 'Running')
$isAdmin = Test-IsAdmin

if ($needServiceWork -and -not $isAdmin -and -not $SkipElevate) {
    $elevExit = Start-ElevatedSelf -Key $KeyPath
    # Re-check service after elevation attempt
    $svc = Get-Service -Name "ssh-agent"
    if ($svc.Status -eq 'Running') {
        Write-Status "OK" "ssh-agent is running after elevation."
    }
    else {
        Write-Status "ERROR" "ssh-agent still not running after elevation (exit $elevExit)."
        Write-Status "NEXT" "Open an elevated PowerShell and run: Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent"
        Write-Status "NEXT" "Or re-run: .\scripts\setup_ssh_agent.ps1 (accept the UAC prompt)."
        exit 1
    }
}
else {
    try {
        if ($svc.StartType -eq 'Disabled' -or $svc.StartType -ne 'Automatic') {
            Set-Service -Name "ssh-agent" -StartupType Automatic -ErrorAction Stop
            Write-Status "OK" "ssh-agent StartupType set to Automatic."
        }
        else {
            Write-Status "OK" "ssh-agent StartupType is already Automatic."
        }
    }
    catch {
        Write-Status "WARN" "Could not set ssh-agent to Automatic: $($_.Exception.Message)"
        if (-not $isAdmin) {
            Write-Status "INFO" "Administrator rights required. Re-run without -SkipElevate to get a UAC prompt."
        }
    }

    try {
        $svc = Get-Service -Name "ssh-agent"
        if ($svc.Status -eq 'Running') {
            Write-Status "OK" "ssh-agent is already running."
        }
        else {
            Start-Service -Name "ssh-agent" -ErrorAction Stop
            Write-Status "OK" "ssh-agent service started."
        }
    }
    catch {
        Write-Status "ERROR" "Could not start ssh-agent: $($_.Exception.Message)"
        if (-not $isAdmin -and $SkipElevate) {
            Write-Status "NEXT" "Re-run without -SkipElevate, or elevate manually."
        }
        exit 1
    }
}

# ssh-add in the current session (works once the Windows service is running)
$alreadyLoaded = $false
try {
    $listOut = & ssh-add -l 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $listOut) {
        $fpLine = (& ssh-keygen -lf $KeyPath 2>$null | Out-String).Trim()
        if ($fpLine -match 'SHA256:([^\s]+)') {
            $fp = $Matches[1]
            if ($listOut -match [regex]::Escape($fp)) {
                $alreadyLoaded = $true
                Write-Status "OK" "Key already loaded in ssh-agent (fingerprint match)."
            }
        }
        elseif ($listOut -notmatch "no identities") {
            # Fingerprint parse failed; if agent has any identities, avoid a blocking re-add in non-interactive hosts
            Write-Status "INFO" "Agent already has identities; skipping ssh-add to avoid passphrase UI hang."
            $alreadyLoaded = $true
        }
    }
}
catch { }

if (-not $alreadyLoaded) {
    Write-Status "INFO" "Running: ssh-add for your key (passphrase prompt may appear in an interactive window)"
    try {
        # Prefer a separate process so a stuck GUI/console prompt cannot hang forever in automation.
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "ssh-add"
        $psi.Arguments = "`"$KeyPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $false
        $addProc = New-Object System.Diagnostics.Process
        $addProc.StartInfo = $psi
        [void]$addProc.Start()
        if (-not $addProc.WaitForExit(120000)) {
            try { $addProc.Kill() } catch { }
            Write-Status "ERROR" "ssh-add timed out after 120 seconds (passphrase prompt unanswered?)."
            Write-Status "NEXT" "In an interactive PowerShell, run: ssh-add `"$KeyPath`""
            exit 1
        }
        if ($addProc.ExitCode -ne 0) {
            $errText = $addProc.StandardError.ReadToEnd()
            Write-Status "ERROR" "ssh-add returned failure (exit $($addProc.ExitCode)). $errText"
            exit 1
        }
        Write-Status "OK" "Key added to ssh-agent."
    }
    catch {
        Write-Status "ERROR" "ssh-add failed: $($_.Exception.Message)"
        exit 1
    }
}

if ($Elevated) {
    Write-Status "OK" "Elevated service setup finished. Key load may also have run in this elevated window."
}

Write-Status "NEXT" "Test GitHub: .\scripts\test_github_ssh.ps1"
Write-Status "NEXT" "If still Permission denied: .\scripts\copy_public_key.ps1 (add key on GitHub)"
exit 0
