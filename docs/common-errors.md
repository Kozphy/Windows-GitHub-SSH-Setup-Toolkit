# Common errors (meaning, likely cause, safe fix)

This document focuses on **non-destructive** fixes. This toolkit does not rewrite history, force push, delete files, or print private keys.

## Permission denied (publickey)

**Meaning:** The SSH server (here, GitHub) rejected authentication—no acceptable key was offered or matched.

**Likely cause**

- Your public key is not added to GitHub (or added to the wrong account).
- ssh-agent is not running or your key is not loaded (`ssh-add -l` empty).
- You are using a non-default key path and did not add it with `ssh-add`.

**Safe fix**

1. Run `scripts/diagnose_ssh.ps1`.
2. Ensure GitHub has your **public** `.pub` key.
3. Run `scripts/setup_ssh_agent.ps1` (or `ssh-add` your private key path).

---

## Could not open a connection to your authentication agent

**Meaning:** The SSH client cannot talk to `ssh-agent`.

**Likely cause**

- The Windows `ssh-agent` service is stopped or disabled.
- Environment/session issues (less common on modern Windows OpenSSH).

**Safe fix**

1. Start the agent service (the toolkit uses `setup_ssh_agent.ps1` to start it when possible).
2. Re-run `ssh-add -l` to confirm the agent responds.

---

## The agent has no identities

**Meaning:** ssh-agent is reachable, but no private keys have been loaded into it.

**Likely cause**

- You have not run `ssh-add` since reboot (common if keys are not persisted automatically on your setup).
- You created a key in a non-default location and never added it.

**Safe fix**

- Run `scripts/setup_ssh_agent.ps1` or `ssh-add C:\Users\YOU\.ssh\id_ed25519` (your actual path).

---

## Repository not found

**Meaning:** GitHub rejected access to that repo URL (over HTTPS this often looks like a 404-style message).

**Likely cause**

- Wrong owner/repo name in the remote URL.
- You lack permission (private repo).
- Authenticated as the wrong GitHub user for that repo.

**Safe fix**

1. Verify `git remote -v`.
2. Confirm you can open the repo in the browser with the same account you intend to use.
3. Fix the remote URL (`fix_git_remote_ssh.ps1` for SSH form, or adjust HTTPS URL carefully).

---

## `src refspec main` does not match any

**Meaning:** You tried to push or refer to branch `main`, but **your local repo does not have a local branch named `main`** (or you are not on it).

**Likely cause**

- Your default branch is still `master` locally, or you never created `main`.
- You typed `main` but your branch is named differently.

**Safe fix**

- Check `git branch --show-current`.
- Push the branch that actually exists, for example `git push -u origin feature/foo`.

---

## Everything up-to-date but branch not on GitHub

**Meaning:** Your local Git state may be clean, but **no upstream branch exists on the remote** for your current branch—often because you never pushed it.

**Likely cause**

- You committed locally but did not run `git push -u origin <branch>`.

**Safe fix**

- Use `scripts/push_current_branch.ps1` (confirmation required) or run `git push -u origin <branch>` yourself.

---

## Non-fast-forward (rejected)

**Meaning:** The remote branch has commits that your local branch does not include, so a normal push would rewrite remote history (Git blocks that).

**Likely cause**

- Someone else pushed to the branch, or you pushed from another machine, or you reset locally.

**Safe fix**

- Integrate remote changes first (`git pull --rebase` or `git pull` merge), resolve conflicts if any, then push again.
- **Do not** force push unless you fully understand the consequences—this toolkit never runs `git push --force`.
