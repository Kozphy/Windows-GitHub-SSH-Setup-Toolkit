# Manual tests (no automated runner yet)

These scenarios validate the toolkit on a **Windows 10/11** machine with **PowerShell 5.1+** (Windows PowerShell or PowerShell 7). No Python or external dependencies are required.

## Last verified

| Date | Host | Result |
| --- | --- | --- |
| 2026-07-23 | Windows 10/11, PowerShell 5.1, OpenSSH client, Git for Windows | **A–E passed** (D/E exercised cancel/`NO` gates only) |

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

**Verified 2026-07-23:** Pass (`doctor` / `diagnose` exit 0 on a healthy machine).

## Scenario B — GitHub SSH test

1. Run:

   ```powershell
   .\scripts\test_github_ssh.ps1
   ```

**Expect:** Output includes GitHub’s SSH banner. Success contains **“successfully authenticated”**.

**Verified 2026-07-23:** Pass.

## Scenario C — ssh-agent setup (non-destructive except agent/key load)

> This touches your local agent state but does **not** generate keys.

1. Ensure you have a key file (do **not** commit keys). Default expected path: `%USERPROFILE%\.ssh\id_ed25519`.
2. Run:

   ```powershell
   .\scripts\setup_ssh_agent.ps1
   ```

3. Optional: `-KeyPath "C:\Users\YOU\.ssh\id_ed25519"`

**Expect:** Clear `[OK]` / `[WARN]` messages; `ssh-add` may prompt for passphrase.

**Verified 2026-07-23:** Pass (agent already running; fingerprint match; skipped redundant `ssh-add`).

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

**Verified 2026-07-23:** Pass for cancel path (`NO` → “Cancelled. No changes made.”; `origin` unchanged). Confirm/`YES` path not re-applied on this production remote.

## Scenario E — Push current branch (confirmation gate)

1. In a test repo with permission to push, create a branch with a tiny commit.
2. Run:

   ```powershell
   .\scripts\push_current_branch.ps1
   ```

3. Cancel once, then confirm once.

**Expect:** Toolkit never runs `--force`.

**Verified 2026-07-23:** Pass for cancel path (`NO` → “Cancelled. No push performed.”).

## Safety checklist for testers

- Do not paste private keys into issues or chats.
- Prefer PATs only in credential managers—not in repo files.
- If something fails, capture **only** non-sensitive output (redact hostnames if needed).
