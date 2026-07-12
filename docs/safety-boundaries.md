# Safety boundaries

This toolkit is designed to be **beginner-friendly** and **safe-by-default**. It favors diagnosis, clear explanations, and explicit confirmation for anything that changes remotes or publishes data.

## What this toolkit does **not** do

- **Never stores private keys** in the repository or in scripts.
- **Never prints private key contents** (only existence checks and `ssh-add -l` fingerprints when available).
- **Never runs `git push --force`** or other force-push variants.
- **Never rewrites Git history** (no `rebase`/`reset` automation for rewriting published history).
- **Never deletes local files** as part of automation.
- **Never generates** an SSH private key file for you (you run `ssh-keygen` yourself when needed).

## What requires explicit confirmation

- **Changing `git remote` URLs** (`fix_git_remote_ssh.ps1`): you must type `YES` to apply.
- **Pushing to `origin`** (`push_current_branch.ps1`): you must type `YES` to push.
- **Enabling a Disabled `ssh-agent` service** may show a **UAC** prompt (`enable_ssh_agent_service.ps1` / `complete_ssh_setup.ps1`). Elevation is limited to starting/configuring that Windows service—not Git remotes, not key generation, not uploads.

## Why these boundaries exist

SSH and Git mistakes can be scary for beginners. Restricting destructive operations reduces the chance of accidental data loss, accidental history rewriting, or unintended publication—while still helping you fix the most common Windows/GitHub SSH setup issues.

## If you need advanced recovery

For complex history repair or disaster recovery, use Git documentation or experienced review. This toolkit intentionally stays out of that space.
