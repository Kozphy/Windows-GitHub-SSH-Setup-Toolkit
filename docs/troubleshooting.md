# Troubleshooting flow (step-by-step)

Use this as a **diagnose-first** path. The toolkit scripts align with these steps.

## 1) Confirm you are in the right folder

- If Git commands say “not a git repository”, `cd` into your project root (the folder that contains the `.git` directory).

## 2) Run the doctor summary (read-only)

From the toolkit repo (or anywhere):

```powershell
.\scripts\doctor.ps1
```

This prints a compact checklist: Git, SSH, ssh-agent, loaded keys, GitHub auth, and whether `origin` looks like SSH.

## 3) If ssh-agent or keys look wrong, fix SSH first

Symptoms:

- “Could not open a connection to your authentication agent”
- “agent has no identities”
- `ssh-add -l` shows nothing
- `Permission denied (publickey)`

Actions:

1. Preferred: `.\scripts\ensure_github_ssh.ps1` (may show a UAC prompt to enable `ssh-agent`).
2. Or: `.\scripts\setup_ssh_agent.ps1` then `.\scripts\test_github_ssh.ps1`.
3. If GitHub still denies the key: `.\scripts\copy_public_key.ps1` and paste into GitHub SSH settings.

Expected success includes GitHub’s **“successfully authenticated … no shell access”** message—that is normal.

## 4) If GitHub SSH works, verify your remote URL

```powershell
git remote -v
```

- If you intend to use SSH, `origin` should look like `git@github.com:OWNER/REPO.git`.
- If it is HTTPS and you want SSH, use `.\scripts\fix_git_remote_ssh.ps1` (requires typing `YES` to confirm).

## 5) If commits exist locally but GitHub does not show your branch

Symptoms:

- `git status` shows you are ahead, or you never pushed this branch before.

Actions:

1. Run `.\scripts\push_current_branch.ps1` and confirm with `YES`.
2. If push fails with non-fast-forward, pull/rebase/merge first, then push again.

## 6) Still stuck

Run the full report:

```powershell
.\scripts\diagnose_ssh.ps1
```

Then read:

- `docs/common-errors.md`
- `docs/github-ssh-success-message.md`
