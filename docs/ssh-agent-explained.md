# ssh-agent on Windows (explained)

## What ssh-agent does

`ssh-agent` is a small background service that holds **private keys in memory** after you unlock them once. When you use SSH (for example, `git@github.com` remotes), the SSH client can ask the agent to prove your identity instead of reading your key file for every single connection.

On Windows 10 and Windows 11, OpenSSH typically installs an **ssh-agent Windows service**. When that service is running and your key has been added with `ssh-add`, Git and `ssh` can authenticate without repeatedly asking for your passphrase.

## Why `ssh-add` matters

If your private key is protected by a passphrase (recommended), then **without ssh-agent** you may be prompted often—sometimes once per Git operation or SSH connection.

After you run `ssh-add` (or the toolkit’s `setup_ssh_agent.ps1`), you enter the passphrase **once** (for that session or until the key is removed). The agent keeps the unlocked key material in memory so routine Git operations feel smooth.

## Practical mental model

- **Your key files on disk** stay where they are (for example, `%USERPROFILE%\.ssh\id_ed25519`).
- **ssh-agent** is the process that answers “prove you have this key” when connecting to GitHub.
- **ssh-add** loads your key into the agent so those prompts do not repeat endlessly.

## Related toolkit scripts

- `scripts/setup_ssh_agent.ps1` — enable/start the service (when possible) and `ssh-add` your key path (does **not** create keys).
- `scripts/diagnose_ssh.ps1` — checks whether the agent is running and whether identities are loaded (`ssh-add -l`).
