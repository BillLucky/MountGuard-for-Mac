# Security Policy

## Scope

MountGuard is a local-first macOS utility. The main security goals are:

- protect disk data from accidental corruption
- avoid hidden write paths
- avoid leaking local credentials or secrets
- keep all risky operations explicit and auditable

## Secret Handling

- Never commit `.env`, tokens, private keys, certificates, or provisioning files.
- Keep local secrets outside the repository.
- Review `.gitignore` before publishing or pushing.
- Run a quick grep scan before opening a public repository.

## Disk Safety Reporting

Please report:

- any case where MountGuard writes unexpectedly
- any case where eject happens while the disk is still busy
- any case where a self-test escapes `.mountguard-selftest`
- any crash or hang triggered by removable disks

## Disclosure

If you discover a vulnerability or a disk-safety issue, open a private report first if possible, then provide:

- macOS version
- Mac model / architecture
- filesystem type
- exact reproduction steps
- expected behavior and actual behavior
