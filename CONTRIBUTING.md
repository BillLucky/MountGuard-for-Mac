# Contributing

## Principles

- Safety first: never add hidden write paths to external disks.
- Native first: prefer macOS system frameworks and official commands.
- Explicit over implicit: all state-changing disk actions must be user-triggered.
- Small surfaces: keep functions short, data flow obvious, and responsibilities single-purpose.

## Local Development

```bash
swift test --disable-sandbox
swift run --disable-sandbox mountguardctl list
./scripts/run-local-app.sh
```

## Architecture Discipline

- Update `CLAUDE.md` whenever file structure or module boundaries change.
- Keep system-facing logic in `MountGuardKit`.
- Keep GUI state orchestration in `DiskDashboardModel`.
- Reuse the same services from GUI and CLI instead of duplicating logic.

## Disk Safety Rules

- Only operate on user-selected external disks.
- Self-tests may only touch the hidden workspace `.mountguard-selftest`.
- Never auto-kill processes to make eject succeed.
- Never attempt write tests when the volume reports read-only.

## Pull Requests

- Describe the user-visible behavior change.
- Describe disk-safety impact.
- Include the verification commands you ran.
- Include screenshots for GUI changes when relevant.
