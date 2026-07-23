# Changelog

## v1.0.0 — 2026-07-23

First portfolio-ready release of the Windows GitHub SSH Setup Toolkit.

### Highlights

- Diagnose-first workflow: `doctor.ps1` and `diagnose_ssh.ps1`
- One-shot repair: `ensure_github_ssh.ps1` (agent + verify + public-key help)
- Windows realities covered: Disabled `ssh-agent` (UAC), public key not on GitHub, Git-for-Windows vs Windows OpenSSH mismatch
- Safe-by-default mutating scripts (`YES` confirmation; never force push; never print private keys)

### Scripts

- `doctor.ps1`, `diagnose_ssh.ps1`, `test_github_ssh.ps1`
- `setup_ssh_agent.ps1`, `ensure_github_ssh.ps1`, `copy_public_key.ps1`
- `write_github_ssh_config.ps1`, `fix_git_ssh_command.ps1`
- `fix_git_remote_ssh.ps1`, `push_current_branch.ps1`

### Docs and examples

- Troubleshooting, common errors, safety boundaries, SSH vs HTTPS
- Before/after doctor samples under `examples/`

### Manual verification (2026-07-23)

Scenarios A–E in `tests/README.md` were walked on Windows 10/11 + PowerShell 5.1:

| Scenario | Result |
| --- | --- |
| A Read-only diagnosis | Pass |
| B GitHub SSH test | Pass |
| C ssh-agent setup | Pass |
| D Fix remote (cancel gate) | Pass — cancelled, remote unchanged |
| E Push branch (cancel gate) | Pass — cancelled, no push |
