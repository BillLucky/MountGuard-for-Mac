# Open Source Release Guide

## Before Publishing

- run `swift test --disable-sandbox`
- run `swift run --disable-sandbox mountguardctl list`
- grep the repository for secrets, tokens, `.env`, and private keys
- verify `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, and `LICENSE`
- update `CLAUDE.md` if architecture changed

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
- DMG package once packaging is added

## Important Notes

- do not publish machine-specific paths in docs unless they are examples
- do not publish tokens, provisioning profiles, or local configuration files
- keep the repository safe for anyone to clone and build locally
