# MountGuard

[中文说明](./README.zh-CN.md) | [Development Guide](./docs/DEVELOPMENT.md) | [Testing Guide](./docs/TESTING.md) | [Release Guide](./docs/OPEN_SOURCE_RELEASE.md)

MountGuard is a native macOS app for external disks.

Its job is simple:

- get a disk mounted quickly
- tell you whether it is really writable
- keep NTFS handling conservative instead of reckless
- help you diagnose and repair common blockers before you try risky writes
- let you eject cleanly after copying data

## What It Solves

Many disk tools stop at "the disk exists".

MountGuard goes one step further:

- shows whether the disk is mounted, writable, and safe to use
- gives you one place for mount, open, scan, self-test, doctor, and eject
- blocks unsafe NTFS read/write remount attempts when the diagnosis says "not yet"
- offers a guided Mac-side repair path for common NTFS blockers using `ntfsfix`
- keeps the main workflow fast for exFAT, APFS, and HFS+

## Main Workflow

```text
Plug In Disk
    |
    v
MountGuard refreshes state
    |
    +--> Mounted + Writable ----------> Open in Finder ----------> Copy files
    |
    +--> Mounted + Read-only ---------> Run Disk Doctor ---------> Repair / stay read-only
    |
    +--> Unmounted -------------------> Mount from GUI/menu bar --> Retry
```

## Why It Feels Safe

- No automatic formatting
- No silent process killing
- No fake "writable" label when the path is still blocked
- No write self-test on read-only volumes
- No writes outside the MountGuard-owned self-test workspace
- No NTFS enhanced RW attempt after Disk Doctor marks the volume as blocked

## Disk Doctor

Disk Doctor starts with a read-only diagnosis.

For NTFS volumes it can identify:

- unsafe state caused by Windows fast startup / hibernation residue
- common NTFS corruption signals that require repair before RW remount
- when macOS native verification is not meaningful for this volume
- whether this Mac is ready to run a guided `ntfsfix` repair locally

If the issue is one of the common mount blockers, MountGuard can offer:

```text
Read-only diagnosis
    |
    v
Show repair plan
    |
    v
Ask for user confirmation
    |
    v
Run ntfsfix on macOS
    |
    v
Re-diagnose before suggesting RW remount
```

Important:

- MountGuard can automate a cautious `ntfsfix`-based repair on macOS
- this is useful for common NTFS mount blockers
- it is not a full replacement for Windows `chkdsk`
- if the disk still reports blocked after repair, MountGuard keeps the safer state

## UI Preview

Real screenshots can be added later. For now, here is the product shape:

```text
+---------------------------------------------------------------+
| MountGuard                                                    |
| Disks                         | Backup Drive                  |
|------------------------------|-------------------------------|
| Backup Drive  NTFS  Read Only | Mount Controls               |
| Media SSD     exFAT Writable  | [Mount] [Open] [Scan] [Eject]|
| Archive       APFS  Mounted   |                               |
|                              | Disk Doctor                   |
|                              | [Run Read-Only Diagnosis]     |
|                              | Status: Blocked               |
|                              | - unsafe state detected       |
|                              | - chkdsk recommended          |
|                              | Repair Plan                   |
|                              | [Run Guided Mac Repair]       |
|                              |                               |
|                              | Self-Test / Logs / Overview   |
+---------------------------------------------------------------+
```

## Quick Start

### Install from DMG

1. Open the latest [GitHub Release](https://github.com/BillLucky/MountGuard-for-Mac/releases/latest).
2. Download the latest DMG.
3. Drag `MountGuard.app` into `Applications`.
4. Launch it from `Applications`.

This is the recommended path for normal users.

### Use the GUI

After launch, the normal flow is:

1. select your external disk in the sidebar
2. use `Mount`, `Open`, `Disk Doctor`, or `Safe Eject`
3. only use `Enhanced RW Mount` when Disk Doctor is not blocking the disk

### If first launch is blocked

- right-click `MountGuard.app`
- choose `Open`
- confirm once

Why:

- MountGuard release builds are packaged and bundle-signed for integrity
- until full notarization is in place, Gatekeeper may still ask for one manual confirmation on first launch

## Developer Tools

The commands below are for development, diagnostics, and contributor workflows.

### Run the app from source

```bash
./scripts/run-local-app.sh
```

### CLI helpers

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl doctor <diskIdentifier>
swift run --disable-sandbox mountguardctl doctor-repair <diskIdentifier>
```

### More for contributors

See [Development Guide](./docs/DEVELOPMENT.md) for:

- local environment setup
- build and packaging steps
- signing and first-launch notes
- release workflow


## Filesystem Strategy

- `APFS`, `HFS+`, `exFAT`: stay on the default macOS path for stability and throughput
- `NTFS`: mount safely first, diagnose before risky RW, then attempt enhanced RW only when the evidence says it is appropriate
- multiple external disks: managed from the same main window and menu bar flow

## Current Release Focus

- stable mounting and state refresh
- clear writable vs read-only visibility
- guided NTFS diagnosis and cautious Mac-side repair
- safer eject path with usage scan
- bilingual GUI foundation
- build metadata in the app for traceability

## Developer Notes

- Native macOS stack: `SwiftUI + AppKit + DiskArbitration + diskutil`
- Menu bar app and CLI share the same core services
- `Disk Doctor` and `Enhanced RW Mount` now share the same safety gate
- the repo intentionally avoids private planning files and local secrets

## Roadmap

Future ideas like verified sync, resumable copy, and richer backup flows are tracked in [Advanced Capabilities](./docs/ADVANCED_CAPABILITIES.md) and [Next Phase](./docs/NEXT_PHASE.md).

## For Contributors

- Start here: [CONTRIBUTING.md](./CONTRIBUTING.md)
- Review safety boundaries: [SECURITY.md](./SECURITY.md)
- Understand privacy posture: [PRIVACY.md](./docs/PRIVACY.md)
- Release cleanly: [OPEN_SOURCE_RELEASE.md](./docs/OPEN_SOURCE_RELEASE.md)
