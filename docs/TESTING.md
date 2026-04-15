# Testing Guide

## Goals

- verify that disk discovery is correct
- verify that busy-process scan does not hide blockers
- verify that self-test only touches MountGuard-owned files
- avoid risky writes to real user data

## Automated Checks

```bash
swift test --disable-sandbox
```

Current automated coverage includes:

- `diskutil` plist parsing
- read-only self-test skip behavior
- writable temporary-directory self-test and cleanup

## Real Disk Validation

Use the CLI first:

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl ps <diskIdentifier>
swift run --disable-sandbox mountguardctl selftest <diskIdentifier>
```

Rules:

- only test disks you intentionally selected
- never test on a system volume
- never force writes to a read-only volume
- only let self-test touch `.mountguard-selftest`

## Current Debug Disk

The mounted sample disk `/Volumes/Backup` currently reports:

- filesystem: `NTFS`
- mount mode: `read-only`
- expected self-test behavior: skip write cases safely

This is intentional. A skipped write test is safer than a forced failing write.
