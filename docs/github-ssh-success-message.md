# Why GitHub says “no shell access” (and why that is success)

When you test SSH to GitHub with:

```bash
ssh -T git@github.com
```

You may see a message similar to:

```text
Hi YOUR_USERNAME! You've successfully authenticated, but GitHub does not provide shell access.
```

## This is not a failure

That message means:

1. **SSH authentication succeeded.** GitHub recognized your SSH key and mapped it to an account (shown as `YOUR_USERNAME`).
2. **GitHub is not a general-purpose SSH server.** Unlike logging into a Linux server, you do not get an interactive shell session (`ssh user@host` style).
3. **Git operations use SSH without a shell.** You can still use `git clone`, `git fetch`, `git pull`, and `git push` over `git@github.com:...` remotes.

## What to do next

If authentication succeeds but Git commands fail, the problem is usually **not** this message. Look instead at:

- Remote URL (`git remote -v`) — SSH vs HTTPS
- Branch tracking / push upstream (`git push -u origin <branch>`)
- Repository permissions on GitHub

Use `scripts/diagnose_ssh.ps1` for a structured checklist.
