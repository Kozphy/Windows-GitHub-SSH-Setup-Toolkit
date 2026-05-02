# SSH vs HTTPS for GitHub remotes

Both SSH and HTTPS are supported for Git operations with GitHub. This toolkit focuses on **SSH on Windows** because many beginners hit the same friction: ssh-agent, keys, and confusing success messages.

## SSH remote (common form)

Example:

```text
git@github.com:OWNER/REPO.git
```

**Pros**

- After setup, day-to-day Git often needs **no username/password prompts** for Git operations (keys + agent handle auth).
- Fits teams and workflows that standardize on SSH deploy keys or personal SSH keys.

**Cons**

- Initial setup is more moving parts: keypair, GitHub SSH settings, ssh-agent, `ssh-add`.

## HTTPS remote

Example:

```text
https://github.com/OWNER/REPO.git
```

**Pros**

- Often works quickly for cloning if you already have browser SSO or stored credentials.

**Cons**

- GitHub **does not accept account passwords for Git over HTTPS** for Git operations. You typically use a **Personal Access Token (PAT)** or **Git Credential Manager (GCM)**.
- Credential prompts can confuse beginners (especially when a PAT expires).

## Choosing an approach

- Prefer **SSH** if you want stable CLI authentication tied to an SSH key and you are willing to set up ssh-agent on Windows.
- Prefer **HTTPS** if your organization mandates it or you already have PAT/GCM working reliably.

This toolkit can **optionally** convert `origin` to SSH using `scripts/fix_git_remote_ssh.ps1`, but only after explicit confirmation—HTTPS may already be working for you.
