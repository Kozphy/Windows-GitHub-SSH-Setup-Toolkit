#Requires -Version 5.1
<#
.SYNOPSIS
  Test GitHub SSH authentication with ssh -T git@github.com.
#>

$ErrorActionPreference = 'Continue'

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

Write-Status "INFO" "Running: ssh -T git@github.com"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "ssh"
$psi.Arguments = "-T git@github.com"
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi

try {
    [void]$p.Start()
    if (-not $p.WaitForExit(25000)) {
        try { $p.Kill() } catch { }
        Write-Status "ERROR" "SSH test timed out after 25 seconds. Check network, firewall, or VPN."
        exit 1
    }
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $combined = "$stdout`n$stderr"

    Write-Host "--- Captured output ---"
    Write-Host $combined.TrimEnd()
    Write-Host "--- End output ---"

    $success = $combined -match "successfully authenticated"
    $noShell = $combined -match "does not provide shell access"
    $permDenied = $combined -match "Permission denied"
    $noAgent = $combined -match "Could not open a connection to your authentication agent"
    $noIdentities = $combined -match "Agent has no identities|agent has no identities"

    Write-Host ""

    if ($success) {
        Write-Status "OK" "GitHub SSH authentication succeeded."
        if ($noShell) {
            Write-Status "INFO" "Message 'GitHub does not provide shell access' is expected — it is NOT an error."
            Write-Status "INFO" "GitHub uses SSH only for Git operations (clone, pull, push), not an interactive shell."
        }
        Write-Status "NEXT" "If your repo uses SSH remote: git pull / git push as needed."
        exit 0
    }

    if ($permDenied) {
        Write-Status "ERROR" "Permission denied (publickey)."
        Write-Status "NEXT" "Ensure your public key is on GitHub and your private key is loaded: ssh-add -l"
        Write-Status "NEXT" "Run full flow: .\scripts\complete_ssh_setup.ps1"
        Write-Status "NEXT" "Or: .\scripts\setup_ssh_agent.ps1 then add the .pub key on GitHub"
        exit 1
    }

    if ($noAgent) {
        Write-Status "ERROR" "Cannot connect to ssh-agent."
        Write-Status "NEXT" "Enable agent (may need UAC) then add key: .\scripts\complete_ssh_setup.ps1"
        exit 1
    }

    if ($noIdentities) {
        Write-Status "WARN" "SSH agent has no identities loaded."
        Write-Status "NEXT" "Load a key: .\scripts\setup_ssh_agent.ps1"
        Write-Status "NEXT" "Or full flow: .\scripts\complete_ssh_setup.ps1"
        exit 1
    }

    Write-Status "WARN" "Could not classify GitHub response. Review output above."
    Write-Status "NEXT" "Run full diagnosis: .\scripts\diagnose_ssh.ps1"
    exit 1
}
catch {
    Write-Status "ERROR" "Failed to run ssh: $($_.Exception.Message)"
    exit 1
}
