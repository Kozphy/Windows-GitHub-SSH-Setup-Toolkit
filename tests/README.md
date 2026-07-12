# Manual tests (no automated runner yet)

These scenarios validate the toolkit on a **Windows 10/11** machine with **PowerShell 5.1+** (Windows PowerShell or PowerShell 7). No Python or external dependencies are required.

## Prerequisites for meaningful tests

- Git for Windows installed (`git --version`).
- OpenSSH client available (`ssh -V`).
- Optional: a GitHub account and an SSH key you control (use a **test repo** if you are learning).

## Scenario A — Read-only diagnosis

1. Open PowerShell in **this repository root**.
2. Run:

   ```powershell
   .\scripts\doctor.ps1
   ```

3. Run:

   ```powershell
   .\scripts\diagnose_ssh.ps1
   ```

**Expect:** Sections print (`SYSTEM`, `SSH AGENT`, …). No Git remotes are changed; nothing is pushed. If your machine is not fully configured, `doctor.ps1` may exit with code **1** (this is expected until ssh-agent, keys, and GitHub auth are healthy).

## Scenario B — GitHub SSH test

1. Run:

   ```powershell
   .\scripts\test_github_ssh.ps1
   ```

**Expect:** Output includes GitHub’s SSH banner. Success contains **“successfully authenticated”**.

## Scenario C — Complete SSH setup (agent + key + GitHub test)

> May show a **UAC** prompt if `ssh-agent` is Disabled. Does **not** generate keys.

1. Ensure you have a key file (do **not** commit keys). Default: `%USERPROFILE%\.ssh\id_ed25519`.
2. Run:

   ```powershell
   .\scripts\complete_ssh_setup.ps1
   ```

3. Approve UAC if prompted; enter key passphrase if asked.
4. Expect GitHub success text containing **successfully authenticated**.

Split form:

```powershell
.\scripts\enable_ssh_agent_service.ps1
.\scripts\setup_ssh_agent.ps1
.\scripts\test_github_ssh.ps1
```

## Scenario D — Fix remote (confirmation gate)

> Use a throwaway clone if you are nervous about changing remotes.

1. `cd` into a test clone.
2. Run:

   ```powershell
   ..\Windows-GitHub-SSH-Setup-Toolkit\scripts\fix_git_remote_ssh.ps1 -RepoOwner OWNER -RepoName REPO
   ```

3. Cancel once (`NO`) and verify nothing changes.
4. Run again, type `YES`, verify `git remote -v` shows `git@github.com:OWNER/REPO.git`.

**Expect:** No automatic push; remote changes only after `YES`.

## Scenario E — Push current branch (confirmation gate)

1. In a test repo with permission to push, create a branch with a tiny commit.
2. Run:

   ```powershell
   .\scripts\push_current_branch.ps1
   ```

3. Cancel once, then confirm once.

**Expect:** Toolkit never runs `--force`.

## Safety checklist for testers

- Do not paste private keys into issues or chats.
- Prefer PATs only in credential managers—not in repo files.
- If something fails, capture **only** non-sensitive output (redact hostnames if needed).
