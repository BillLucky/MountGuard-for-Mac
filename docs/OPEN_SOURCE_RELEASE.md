# Open Source Release Guide

## Before Publishing

- run `swift test --disable-sandbox`
- run `swift run --disable-sandbox mountguardctl list`
- run `swift run --disable-sandbox mountguardctl doctor <diskIdentifier>` on at least one real disk
- grep the repository for secrets, tokens, `.env`, and private keys
- verify that `project-goal.md` is ignored and no longer tracked by git
- verify `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`
- update `CLAUDE.md` if architecture changed
- build the DMG with `./scripts/package-dmg.sh <version>`
- prepare bilingual release notes
- verify the release text does not promise unsupported NTFS repair behavior

## Recommended Release Assets

- source code archive
- ASCII workflow diagrams or usage screenshots
- SHA256 checksums for release artifacts
- `MountGuard-<version>.dmg`

## Build The DMG

```bash
./scripts/package-dmg.sh 0.1.3
```

Artifacts will be produced in `dist/`.

## Update GitHub About

```bash
gh repo edit BillLucky/MountGuard-for-Mac \
  --description "Native macOS disk manager for stable mounting, safer read/write workflows, NTFS diagnosis, and guided repair." \
  --homepage "https://github.com/BillLucky/MountGuard-for-Mac"
```

Suggested topics:

```text
macos
swift
swiftui
disk
external-drive
ntfs
mount
diagnostics
data-safety
menu-bar
```

## Create A GitHub Release

```bash
gh release create v0.1.3 \
  dist/MountGuard-0.1.3.dmg \
  dist/MountGuard-0.1.3.dmg.sha256 \
  --title "MountGuard v0.1.3" \
  --notes-file docs/RELEASE_NOTES_v0.1.3.md
```

## Important Notes

- do not publish machine-specific paths in docs unless they are examples
- do not publish private planning files such as `project-goal.md`
- do not publish tokens, provisioning profiles, or local configuration files
- keep the repository safe for anyone to clone and build locally
- describe `Disk Doctor` honestly: guided Mac repair for common NTFS blockers, not a full replacement for `chkdsk`
