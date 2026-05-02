#Requires -Version 5.1
<#
.SYNOPSIS
  Collect GitHub SSH and Git remote diagnostics (read-only).

.PARAMETER Doctor
  Print only the compact one-line summary (same checks as full report).

.NOTES
  Run with: powershell -File .\scripts\diagnose_ssh.ps1
  Do not dot-source this script; it terminates the process with an exit code via [Environment]::Exit.
#>
param(
    [switch]$Doctor
)

$ErrorActionPreference = 'Continue'
$script:ExitCode = 0
$script:DoctorHadWarn = $false

function Write-Status {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}

function Write-DoctorPass {
    param([string]$Message)
    Write-Status "OK" $Message
}

function Write-DoctorWarn {
    param([string]$Message)
    $script:DoctorHadWarn = $true
    Write-Status "WARN" $Message
}

function Test-CommandExists {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-GitHubSshTestResult {
    # ssh sends banner to stderr; merge streams for detection
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
            return @{
                ExitCode = 124
                Combined = "SSH test to GitHub timed out after 25 seconds. Check network, firewall, or try again."
            }
        }
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        $combined = "$out`n$err"
        return @{
            ExitCode = $p.ExitCode
            Combined = $combined
        }
    }
    catch {
        return @{
            ExitCode = -1
            Combined = $_.Exception.Message
        }
    }
}

function Invoke-Diagnosis {
    $results = @{}

    # --- SYSTEM / Git & SSH ---
    $results.GitInstalled = Test-CommandExists "git"
    $results.SshInstalled = Test-CommandExists "ssh"

    # --- SSH AGENT ---
    $agentService = $null
    try {
        $agentService = Get-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
    }
    catch { }
    $results.SshAgentServiceExists = ($null -ne $agentService)
    $results.SshAgentRunning = $false
    if ($agentService) {
        $results.SshAgentRunning = ($agentService.Status -eq 'Running')
    }

    # --- SSH KEYS (never print key material) ---
    $defaultKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
    $results.DefaultKeyPathExists = (Test-Path -LiteralPath $defaultKey)

    $keysLoadedOutput = ""
    $keysLoadedOk = $false
    $identitiesCount = -1
    if ($results.SshInstalled) {
        try {
            $keysLoadedOutput = & ssh-add -l 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                $keysLoadedOk = $true
                # Count non-empty lines that look like key lines (fingerprint type comment)
                $identitiesCount = ($keysLoadedOutput -split "`n" | Where-Object { $_.Trim() -ne "" }).Count
            }
            elseif ($keysLoadedOutput -match "The agent has no identities|could not open a connection to your authentication agent") {
                $keysLoadedOk = $false
            }
        }
        catch {
            $keysLoadedOutput = $_.Exception.Message
        }
    }
    $results.KeysLoadedOutput = $keysLoadedOutput
    $results.KeysLoadedOk = $keysLoadedOk
    $results.IdentitiesCount = $identitiesCount

    # --- GITHUB AUTH ---
    $gh = Get-GitHubSshTestResult
    $results.GhExit = $gh.ExitCode
    $results.GhCombined = $gh.Combined
    $successPhrase = "successfully authenticated"
    $results.GithubAuthOk = ($gh.Combined -match [regex]::Escape($successPhrase))
    $results.PermissionDenied = ($gh.Combined -match "Permission denied")
    $results.NoIdentitiesInTest = ($gh.Combined -match "Agent has no identities|agent has no identities")

    # --- GIT REPOSITORY ---
    $inRepo = $false
    $branch = ""
    $statusShort = ""
    $remoteUrl = ""
    $remoteIsSsh = $false
    $remoteIsHttps = $false

    if ($results.GitInstalled) {
        Push-Location (Get-Location)
        try {
            $top = (git rev-parse --show-toplevel 2>$null).Trim()
            if ($LASTEXITCODE -eq 0 -and $top) {
                $inRepo = $true
                Set-Location $top
                $branch = (git branch --show-current 2>$null).Trim()
                $statusShort = (git status -sb 2>$null | Out-String).Trim()
                $remoteUrl = (git remote get-url origin 2>$null).Trim()
                if ($remoteUrl) {
                    if ($remoteUrl -match '^git@github\.com:' -or $remoteUrl -match '^ssh://git@github\.com/') {
                        $remoteIsSsh = $true
                    }
                    elseif ($remoteUrl -match '^https://github\.com/') {
                        $remoteIsHttps = $true
                    }
                }
            }
        }
        finally {
            Pop-Location
        }
    }

    $results.InGitRepo = $inRepo
    $results.CurrentBranch = $branch
    $results.StatusShort = $statusShort
    $results.OriginUrl = $remoteUrl
    $results.OriginIsSsh = $remoteIsSsh
    $results.OriginIsHttps = $remoteIsHttps

    return $results
}

function Write-FullReport {
    param($r)

    Write-Host ""
    Write-Host "========== SYSTEM =========="
    if ($r.GitInstalled) { Write-Status "OK" "Git is installed." }
    else { Write-Status "ERROR" "Git is not installed or not on PATH."; $script:ExitCode = 1 }

    if ($r.SshInstalled) { Write-Status "OK" "SSH client is available." }
    else { Write-Status "ERROR" "SSH client not found on PATH."; $script:ExitCode = 1 }

    Write-Host ""
    Write-Host "========== SSH AGENT =========="
    if (-not $r.SshAgentServiceExists) {
        Write-Status "WARN" "ssh-agent Windows service not found (unexpected on Windows 10/11 with OpenSSH)."
    }
    else {
        Write-Status "INFO" "ssh-agent service is present."
        if ($r.SshAgentRunning) { Write-Status "OK" "ssh-agent is running." }
        else { Write-Status "WARN" "ssh-agent is not running. Run scripts\setup_ssh_agent.ps1 or start the service."; $script:ExitCode = 1 }
    }

    Write-Host ""
    Write-Host "========== SSH KEYS =========="
    $defaultKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
    Write-Status "INFO" "Default key path checked: $defaultKey (existence only, contents never read)."
    if ($r.DefaultKeyPathExists) { Write-Status "OK" "File exists: id_ed25519" }
    else { Write-Status "WARN" "No id_ed25519 at default path. You may use another key; add it with ssh-add." }

    Write-Status "INFO" "ssh-add -l (listing fingerprints only):"
    Write-Host $r.KeysLoadedOutput
    if ($r.KeysLoadedOk) { Write-Status "OK" "At least one key identity is loaded in the agent." }
    else {
        Write-Status "WARN" "No loaded identities, or agent unreachable. See ssh-add and ssh-agent setup."
        $script:ExitCode = 1
    }

    Write-Host ""
    Write-Host "========== GITHUB AUTH =========="
    Write-Status "INFO" "Running: ssh -T git@github.com"
    # Do not treat full stderr as secret; it is GitHub's public banner. Truncate for readability.
    $snippet = ($r.GhCombined -split "`n" | Select-Object -First 8) -join "`n"
    Write-Host $snippet
    if ($r.GithubAuthOk) {
        Write-Status "OK" "GitHub SSH authentication succeeded (see message about 'no shell access' — that is normal)."
    }
    elseif ($r.PermissionDenied) {
        Write-Status "ERROR" "Permission denied (publickey). Key not on GitHub, wrong key, or agent has no key."
        $script:ExitCode = 1
    }
    elseif ($r.GhCombined -match "Could not open a connection to your authentication agent") {
        Write-Status "ERROR" "Cannot reach ssh-agent."
        $script:ExitCode = 1
    }
    elseif ($r.GhExit -eq 124 -or $r.GhCombined -match "timed out after 25 seconds") {
        Write-Status "WARN" "GitHub SSH test timed out. Check network or VPN, then retry."
        $script:ExitCode = 1
    }
    else {
        Write-Status "WARN" "Could not confirm GitHub success message. Review output above."
        $script:ExitCode = 1
    }

    Write-Host ""
    Write-Host "========== GIT REPOSITORY =========="
    if (-not $r.InGitRepo) {
        Write-Status "INFO" "Current directory is not inside a Git repository."
        Write-Status "NEXT" "cd into your project folder (the one containing .git), then re-run this script."
    }
    else {
        Write-Status "OK" "Inside a Git repository."
        Write-Status "INFO" "Current branch: $($r.CurrentBranch)"
        Write-Host "--- git status -sb ---"
        Write-Host $r.StatusShort
    }

    Write-Host ""
    Write-Host "========== REMOTE =========="
    if (-not $r.InGitRepo) {
        Write-Status "INFO" "No origin remote to show (not in a repo)."
    }
    elseif (-not $r.OriginUrl) {
        Write-Status "WARN" "No 'origin' remote configured."
    }
    else {
        Write-Status "INFO" "origin URL: $($r.OriginUrl)"
        if ($r.OriginIsSsh) { Write-Status "OK" "origin uses SSH form." }
        elseif ($r.OriginIsHttps) {
            Write-Status "INFO" "origin uses HTTPS. HTTPS works but often needs a PAT or Git Credential Manager."
        }
        else { Write-Status "INFO" "origin URL form not classified as GitHub SSH or HTTPS." }
    }

    Write-Host ""
    Write-Host "========== RECOMMENDED NEXT STEPS =========="
    $steps = @()
    if (-not $r.SshAgentRunning) { $steps += "Start and enable ssh-agent: run scripts\setup_ssh_agent.ps1" }
    if (-not $r.KeysLoadedOk -and $r.DefaultKeyPathExists) { $steps += "Load your key: ssh-add `"$defaultKey`"" }
    if (-not $r.DefaultKeyPathExists -and -not $r.KeysLoadedOk) {
        $steps += 'Create a key (you run locally): ssh-keygen -t ed25519 -C "your_email@example.com"'
        $steps += "Add the public key to GitHub (Settings -> SSH keys), then ssh-add your private key."
    }
    if (-not $r.GithubAuthOk) { $steps += "Verify GitHub SSH: scripts\test_github_ssh.ps1" }
    if ($r.InGitRepo -and $r.OriginIsHttps) {
        $steps += "Optional: switch origin to SSH with scripts\fix_git_remote_ssh.ps1 (confirmation required), or keep HTTPS and use PAT/GCM."
    }
    if ($r.InGitRepo -and $r.OriginIsSsh -and $r.GithubAuthOk -and $r.CurrentBranch) {
        $steps += "Push current branch: git push -u origin $($r.CurrentBranch)  (or scripts\push_current_branch.ps1 with confirmation)"
    }
    if ($steps.Count -eq 0) {
        Write-Status "OK" "No critical issues detected by this checklist."
    }
    else {
        foreach ($s in $steps) { Write-Status "NEXT" $s }
    }
    Write-Host ""
}

function Write-DoctorSummary {
    param($r)

    Write-Host ""
    Write-Status "INFO" "doctor: compact summary (read-only, no changes)"

    if ($r.GitInstalled) { Write-DoctorPass "Git installed" } else { Write-DoctorWarn "Git not installed or not on PATH" }
    if ($r.SshInstalled) { Write-DoctorPass "SSH installed" } else { Write-DoctorWarn "SSH client not on PATH" }

    if ($r.SshAgentRunning) { Write-DoctorPass "ssh-agent running" }
    else { Write-DoctorWarn "ssh-agent is not running (start service or run setup_ssh_agent.ps1)" }

    if ($r.KeysLoadedOk) { Write-DoctorPass "SSH key loaded (ssh-add -l)" }
    else { Write-DoctorWarn "No SSH key loaded in agent (ssh-add -l)" }

    if ($r.GithubAuthOk) { Write-DoctorPass "GitHub authentication succeeded" }
    else { Write-DoctorWarn "GitHub SSH authentication not confirmed (run test_github_ssh.ps1)" }

    if ($r.InGitRepo) {
        if ($r.OriginIsSsh) { Write-DoctorPass "origin uses SSH" }
        elseif ($r.OriginUrl) { Write-DoctorWarn "origin does not use SSH URL (HTTPS or other)" }
        else { Write-DoctorWarn "origin remote missing or empty" }

        if ($r.OriginIsSsh -and $r.GithubAuthOk -and $r.CurrentBranch) {
            Write-Status "NEXT" "git push -u origin $($r.CurrentBranch)"
        }
        elseif (-not $r.OriginIsSsh -and $r.OriginUrl) {
            Write-Status "INFO" "See docs\ssh-vs-https.md if you want SSH instead of HTTPS."
        }
    }
    else {
        Write-Status "INFO" "Not inside a Git repo — skipped origin/push summary."
    }
    Write-Host ""
}

# --- main ---
$r = Invoke-Diagnosis

if ($Doctor) {
    Write-DoctorSummary $r
}
else {
    Write-FullReport $r
}

$finalExit = [int]$script:ExitCode
if ($Doctor -and $script:DoctorHadWarn) {
    $finalExit = 1
}
[Environment]::Exit($finalExit)
