# Enabling ssh-agent when it is Disabled (Administrator)

On many Windows 10/11 machines, the **OpenSSH Authentication Agent** (`ssh-agent`) service starts as **Disabled**. Then commands like these fail with *Access is denied*:

```powershell
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

## What this toolkit does

1. **`scripts/enable_ssh_agent_service.ps1`**  
   Sets StartupType to **Automatic** and starts the service. If you are not Administrator, it requests a **UAC elevation** (one elevated helper process), then returns.

2. **`scripts/setup_ssh_agent.ps1`**  
   Calls the enable step (with UAC if needed), then runs **`ssh-add`** as your normal user (so your passphrase prompt stays in your session).

3. **`scripts/complete_ssh_setup.ps1`**  
   Runs setup + **`ssh -T git@github.com`** in one flow.

## Recommended one-command flow

From the repo root (normal PowerShell is fine; approve UAC if prompted):

```powershell
.\scripts\complete_ssh_setup.ps1
```

Equivalent manual steps (Administrator window for the first two lines):

```powershell
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
ssh -T git@github.com
```

## Safety notes

- Elevation is used **only** to configure/start the `ssh-agent` Windows service.
- Scripts do **not** generate keys, rewrite remotes, force-push, or upload anything.
- Private key contents are never printed.

## If UAC is cancelled

Re-run `.\scripts\complete_ssh_setup.ps1`, or open **PowerShell as Administrator** and run `.\scripts\enable_ssh_agent_service.ps1`, then `.\scripts\setup_ssh_agent.ps1` in a normal window.
