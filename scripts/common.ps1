# Shared helpers for Windows GitHub SSH Setup Toolkit scripts.
# Dot-source from other scripts: . "$PSScriptRoot\common.ps1"

function Write-Status {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('OK', 'INFO', 'WARN', 'ERROR', 'NEXT')]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host "[$Level] $Message"
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SshAgentService {
    return Get-Service -Name 'ssh-agent' -ErrorAction SilentlyContinue
}

function Test-SshAgentRunning {
    $svc = Get-SshAgentService
    return ($null -ne $svc -and $svc.Status -eq 'Running')
}

function Enable-SshAgentService {
    <#
    .SYNOPSIS
      Set ssh-agent StartupType to Automatic and start the service.
      Requires Administrator when the service is Disabled or cannot be started.
    #>
    $svc = Get-SshAgentService
    if (-not $svc) {
        Write-Status 'ERROR' "Windows service 'ssh-agent' not found. Install OpenSSH Client (Windows Settings -> Optional features)."
        return $false
    }

    try {
        if ($svc.StartType -ne 'Automatic') {
            Set-Service -Name 'ssh-agent' -StartupType Automatic -ErrorAction Stop
            Write-Status 'OK' 'ssh-agent StartupType set to Automatic.'
        }
        else {
            Write-Status 'OK' 'ssh-agent StartupType is already Automatic.'
        }
    }
    catch {
        Write-Status 'ERROR' "Could not set ssh-agent to Automatic: $($_.Exception.Message)"
        return $false
    }

    try {
        $svc = Get-SshAgentService
        if ($svc.Status -eq 'Running') {
            Write-Status 'OK' 'ssh-agent is already running.'
            return $true
        }
        Start-Service -Name 'ssh-agent' -ErrorAction Stop
        Write-Status 'OK' 'ssh-agent service started.'
        return $true
    }
    catch {
        Write-Status 'ERROR' "Could not start ssh-agent: $($_.Exception.Message)"
        return $false
    }
}

function Request-ElevatedSshAgentEnable {
    <#
    .SYNOPSIS
      Re-launch enable_ssh_agent_service.ps1 with UAC elevation and wait.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnableScriptPath
    )

    if (-not (Test-Path -LiteralPath $EnableScriptPath)) {
        Write-Status 'ERROR' "Elevation helper not found: $EnableScriptPath"
        return $false
    }

    Write-Status 'INFO' 'Administrator rights are required to enable/start ssh-agent when it is Disabled.'
    Write-Status 'INFO' 'A UAC prompt will appear. Approve it to continue.'

    $argList = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', $EnableScriptPath
        '-Elevated'
    )

    try {
        $proc = Start-Process -FilePath 'powershell.exe' `
            -Verb RunAs `
            -ArgumentList $argList `
            -Wait `
            -PassThru
        if ($null -eq $proc) {
            Write-Status 'ERROR' 'Elevation was cancelled or failed to start.'
            return $false
        }
        if ($proc.ExitCode -ne 0) {
            Write-Status 'ERROR' "Elevated enable script exited with code $($proc.ExitCode)."
            return $false
        }
        return (Test-SshAgentRunning)
    }
    catch {
        Write-Status 'ERROR' "UAC elevation failed: $($_.Exception.Message)"
        Write-Status 'NEXT' 'Open PowerShell as Administrator and run: .\scripts\enable_ssh_agent_service.ps1'
        return $false
    }
}

function Get-DefaultSshKeyPath {
    return (Join-Path $env:USERPROFILE '.ssh\id_ed25519')
}

function Test-CommandExists {
    param([string]$Name)
    return ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}
