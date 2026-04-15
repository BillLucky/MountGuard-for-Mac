# Open Source Release Guide

## Before Publishing

- run `swift test --disable-sandbox`
- run `swift run --disable-sandbox mountguardctl list`
- grep the repository for secrets, tokens, `.env`, and private keys
- verify `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`
- update `CLAUDE.md` if architecture changed
- build the DMG with `./scripts/package-dmg.sh <version>`

## Initialize Git

```bash
git init -b main
git add .
git commit -m "Initial MountGuard MVP"
```

## Create Public GitHub Repository

```bash
gh repo create MountGuard-for-Mac --public --source=. --remote=origin --push
```

## Recommended Release Assets

- source code archive
- usage screenshots
- SHA256 checksums for release artifacts
- `MountGuard-<version>.dmg`

## Create the First DMG

```bash
./scripts/package-dmg.sh 0.1.0
```

Artifacts will be produced in `dist/`.

## Create a GitHub Release

```bash
gh release create v0.1.0 \
  dist/MountGuard-0.1.0.dmg \
  dist/MountGuard-0.1.0.dmg.sha256 \
  --title "MountGuard v0.1.0" \
  --notes "First public MVP release with bilingual GUI, busy-process scan, self-test, and safe eject."
```

## Important Notes

- do not publish machine-specific paths in docs unless they are examples
- do not publish tokens, provisioning profiles, or local configuration files
- keep the repository safe for anyone to clone and build locally
