# Development Guide

## Goal

This guide is for contributors who want to build, debug, package, and release MountGuard locally.

MountGuard is a native macOS app, not a CLI-first project.

The normal user path is:

1. download the latest DMG from GitHub Releases
2. drag `MountGuard.app` to `Applications`
3. launch the GUI

The CLI and scripts exist to support development, diagnostics, and release work.

## Requirements

- macOS
- Xcode and Command Line Tools
- Swift toolchain compatible with the project
- `gh` for GitHub release workflows

Optional but useful for NTFS work:

- `ntfs-3g`
- `ntfsfix`
- macFUSE

Homebrew example:

```bash
brew install gh ntfs-3g
brew install --cask macfuse
```

## Project Layout

```text
Sources/MountGuardApp      GUI and app wiring
Sources/MountGuardKit      Disk services, state, safety gates
Sources/mountguardctl      Developer CLI
scripts/                   Local run and DMG packaging helpers
docs/                      Release, testing, and contributor docs
```

## Local Build

Run tests first:

```bash
swift test --disable-sandbox
```

Build the app target:

```bash
swift build -c release --product MountGuardApp --disable-sandbox
```

Run the GUI in development:

```bash
./scripts/run-local-app.sh
```

Useful developer CLI commands:

```bash
swift run --disable-sandbox mountguardctl list
swift run --disable-sandbox mountguardctl doctor <diskIdentifier>
swift run --disable-sandbox mountguardctl doctor-repair <diskIdentifier>
swift run --disable-sandbox mountguardctl ps <diskIdentifier>
swift run --disable-sandbox mountguardctl selftest <diskIdentifier>
```

## Packaging

Build a DMG:

```bash
./scripts/package-dmg.sh 0.1.5
```

Artifacts land in `dist/`.

What the packaging script does:

- builds the release app bundle
- injects version, build date, and git commit metadata
- clears stale extended attributes
- signs the final app bundle for integrity
- writes a DMG with the app, `Applications` shortcut, and quick-start note

## Signing And First Launch

Current release packages are bundle-signed for integrity.

This fixes the "app is damaged" class of packaging failure.

However, truly frictionless first launch still needs:

- Apple Developer ID
- notarization

Until notarization is wired in, some Macs may still require:

1. right-click `MountGuard.app`
2. choose `Open`
3. confirm once

## Release Workflow

1. run tests
2. verify the GUI still works for the primary disk flows
3. build the DMG
4. update README and release notes
5. commit with a precise message
6. push `main`
7. publish with `gh release create`

See [OPEN_SOURCE_RELEASE.md](./OPEN_SOURCE_RELEASE.md) for the checklist.

## Disk Safety Rules

- never write outside MountGuard-owned test space during self-test
- never force RW on a blocked NTFS volume
- never add silent fallback writes
- always prefer diagnosis before repair, and repair before risky remount

## Common Debug Paths

Check the installed tools:

```bash
which ntfs-3g
which ntfsfix
```

Inspect code signing:

```bash
codesign --verify --deep --strict .build/mountguard-release/MountGuard.app
spctl --assess --type execute -vv .build/mountguard-release/MountGuard.app
```

Check git cleanliness before release:

```bash
git status --short
```

## Contribution Style

- keep functions short
- keep user-facing text concise
- keep the GUI action-first and explanation-second
- push detail into help popovers or docs when it is not needed on the main path
- keep disk-safety boundaries explicit
