# MountGuard

[中文说明](./README.zh-CN.md) | [Testing Guide](./docs/TESTING.md) | [Release Guide](./docs/OPEN_SOURCE_RELEASE.md)

MountGuard helps Mac users work with external disks more calmly.

It shows what is mounted, what is blocking an eject, what is safe to do next, and how to test the disk path without touching user files outside a MountGuard-owned workspace.

## Why It Exists

Plugging in an external disk should feel boring and safe.

In reality, it often feels like this:

- the disk mounts but you are not sure whether it is writable
- you copy files for a long time and do not know what is safe to retry
- macOS says the disk is busy but does not tell you who is holding it
- you want a quick confidence check without risking your own folders

MountGuard starts by solving those problems well. Then it grows into higher-level workflows like verified sync and resumable backup.

## What You Can Do Today

- See external volumes in a native macOS window and menu bar
- Open the mounted disk in Finder
- Inspect filesystem, bus, SMART status, free space, and mount mode
- Scan for blocking processes before ejecting
- Run a safer eject flow: `sync -> unmount -> eject`
- Run a disk self-test that only touches `.mountguard-selftest`
- Switch the GUI between English and Chinese

## Quick Start

### 1. Launch the app

```bash
./scripts/run-local-app.sh
```

### 2. Inspect disks from CLI

```bash
swift run --disable-sandbox mountguardctl list
```

### 3. See what is blocking a disk

```bash
swift run --disable-sandbox mountguardctl ps disk4s2
```

### 4. Run the safe self-test

```bash
swift run --disable-sandbox mountguardctl selftest disk4s2
```

### 5. Eject only when you really mean it

```bash
swift run --disable-sandbox mountguardctl eject disk4s2
```

## Screenshots

### Main Window

![MountGuard main window](./assets/screenshots/main-window.svg)

### Menu Bar Panel

![MountGuard menu bar panel](./assets/screenshots/menu-bar.svg)

### Self-Test Workflow

![MountGuard self-test workflow](./assets/screenshots/self-test.svg)

## A Friendly Mental Model

- `Open`: jump into the disk in Finder
- `Scan Usage`: ask who is still holding the disk
- `Run Self-Test`: verify the I/O path using MountGuard's own hidden workspace
- `Safe Eject`: flush, unmount, and eject in a safer order

If a volume is read-only, MountGuard respects that and skips write self-tests instead of pretending everything is fine.

## Real Usage Stories

### “I just want to unplug safely.”

Open MountGuard, pick the disk, run `Scan Usage`, and then `Safe Eject`.

### “I am not sure whether the disk path is healthy.”

Run the self-test. It creates files only inside `.mountguard-selftest`, validates read/write behavior, and cleans up after itself.

### “I mainly live in Terminal.”

Use:

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl ps <diskIdentifier>
swift run --disable-sandbox mountguardctl selftest <diskIdentifier>
swift run --disable-sandbox mountguardctl eject <diskIdentifier>
```

## Safety Promises

- No automatic formatting
- No automatic `fsck`
- No silent process killing
- No hidden remount tricks
- No write self-test on read-only volumes
- No writes outside MountGuard-owned test workspace

## Current Validation

- `swift test --disable-sandbox` passes
- The current debug disk `/Volumes/Backup` is correctly identified as `NTFS` and `read-only`
- Real self-test on that disk is intentionally skipped instead of forcing unsafe writes
- Busy-process scan has been switched to a filesystem-level strategy so large disks stay responsive

## Looking Ahead

MountGuard is not meant to stop at “a better eject button”.

Planned higher-level capabilities include:

- resumable copy and retry
- verified incremental sync
- checksum-aware backup workflows
- copy health reporting for large transfers

See [Advanced Capabilities](./docs/ADVANCED_CAPABILITIES.md) for the product direction.

## For Contributors

- Start here: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Review safety boundaries: [SECURITY.md](./SECURITY.md)
- Understand privacy posture: [PRIVACY.md](./docs/PRIVACY.md)
- Release cleanly: [OPEN_SOURCE_RELEASE.md](./docs/OPEN_SOURCE_RELEASE.md)
