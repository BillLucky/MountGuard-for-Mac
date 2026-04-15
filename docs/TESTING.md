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

For normal product validation, use the GUI first:

- install the latest DMG from GitHub Releases
- open the app from `Applications`
- validate mount, open, Disk Doctor, self-test, and safe eject from the GUI

Use the CLI when you need scripted diagnosis or repeatable contributor checks:

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl doctor <diskIdentifier>
swift run --disable-sandbox mountguardctl ps <diskIdentifier>
swift run --disable-sandbox mountguardctl selftest <diskIdentifier>
```

Rules:

- only test disks you intentionally selected
- never test on a system volume
- never force writes to a read-only volume
- only let self-test touch `.mountguard-selftest`

## Sample Safety Expectation

If a real test disk is currently read-only:

- Disk Doctor should explain why
- self-test should skip write checks safely
- MountGuard should not pretend that RW is available

A skipped write test is safer than a forced failing write.
