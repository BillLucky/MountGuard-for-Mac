# Privacy Notes

MountGuard is designed as a local-first utility.

## What It Does Not Do

- no telemetry
- no analytics
- no background upload of disk metadata
- no cloud dependency for core features

## What It Touches

- `diskutil` for disk discovery and eject operations
- `lsof` for busy-process inspection
- a hidden self-test workspace named `.mountguard-selftest` on the selected writable volume

## User Data Promise

- no disk content is scanned beyond what is needed for explicit user actions
- self-test only creates and deletes files it owns
- read-only volumes are respected and write tests are skipped
