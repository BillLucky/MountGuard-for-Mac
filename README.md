# MountGuard

MountGuard is a native macOS utility for safe external disk discovery, inspection, self-test, and ejection.

MountGuard 是一个面向 macOS 的原生外接磁盘管理工具，强调安全发现、状态可视化、受控自测与稳妥移除。

## Highlights

- Native macOS stack: `SwiftUI + AppKit + DiskArbitration + diskutil`
- Read-only inventory by default; no hidden remount, no silent repair
- Menu bar app + CLI with shared system boundary
- Busy-process scan before ejection
- Self-test only touches a MountGuard-owned hidden workspace
- Bilingual foundation for GUI and docs: Chinese + English

## Current Scope

- Discover external volumes
- Show mount point, filesystem, bus, SMART, space usage
- Open mounted volumes in Finder
- Scan blocking processes with `lsof`
- Run safer eject flow: `sync -> unmount -> eject`
- Run disk self-test on a MountGuard-owned workspace
- Provide CLI commands for `list`, `ps`, `selftest`, `eject`

## Safety Boundaries

- MountGuard never formats a disk automatically.
- MountGuard never runs `fsck` automatically.
- MountGuard never kills user or system processes automatically.
- Any state-changing action must be triggered explicitly by the user.
- The current debug disk `/Volumes/Backup` is detected as `NTFS` and `read-only`, so write self-tests are skipped by design.

## Local Run

### GUI

```bash
./scripts/run-local-app.sh
```

### CLI

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl ps disk4s2
swift run --disable-sandbox mountguardctl selftest disk4s2
swift run --disable-sandbox mountguardctl eject disk4s2
```

Note: `eject` performs a real safe-eject workflow. Only run it when the disk can be removed.

注意：`eject` 会真实触发安全移除流程，请仅在你确认可以拔盘时执行。

## Real-World Validation

- `swift test --disable-sandbox` passes
- CLI correctly detects `/Volumes/Backup`
- Self-test on a writable temporary directory passes in automated tests
- Self-test on the mounted NTFS read-only disk is expected to skip write cases instead of forcing risky writes

## Repository Guide

- `Sources/MountGuardKit`: system-facing services and domain models
- `Sources/MountGuardApp`: desktop GUI and menu bar experience
- `Sources/mountguardctl`: CLI entrypoint
- `Tests/MountGuardKitTests`: parser and self-test regression coverage
- `docs/TESTING.md`: testing policy and real disk validation rules
- `docs/OPEN_SOURCE_RELEASE.md`: public release and GitHub workflow
- `docs/PRIVACY.md`: privacy and secret-handling contract

## Open Source Rules

- Do not commit secrets, tokens, certificates, or `.env` files.
- Keep all risky disk operations explicit and reviewable.
- Document architecture changes in `CLAUDE.md`.
- Prefer reproducible local verification before publishing.

## Roadmap

- Rule engine based on disk UUID
- Visual process release workflow before eject
- Exportable operation logs
- Config import/export
- DMG packaging and signed distribution
