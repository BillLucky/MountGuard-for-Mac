# Advanced Capabilities Roadmap

MountGuard should eventually help with more than mounting and ejecting.

This document captures the next layer of user value: safer copy, resumable transfer, incremental sync, and verified backup flows.

## Problem Space

Users do not only ask:

- “Can I mount this disk?”
- “Can I eject this disk?”

They also ask:

- “My copy failed halfway. What should I retry?”
- “Can I sync only what changed?”
- “Can I prove the copied files are correct?”
- “Can I copy from Mac to external disk and also back from the external disk to Mac?”

## Capability Direction

### 1. Verified Incremental Sync

Goal:

- sync only changed files
- preserve structure
- detect conflict and overwrite risk early
- verify copied content with checksums

Possible design:

- build a file manifest for source and destination
- compare by path, size, mtime, and optional checksum
- support two directions:
  - Mac -> external disk
  - external disk -> Mac

### 2. Resumable Copy Sessions

Goal:

- allow users to continue after disconnects, crashes, or partial copies

Possible design:

- persist copy session metadata locally
- mark completed, pending, failed, and checksum-mismatch files
- allow “resume”, “retry failed”, and “revalidate copied files”

### 3. Copy Health + Integrity Report

Goal:

- make long-running copy operations understandable

Possible design:

- progress by file count, bytes, speed, ETA
- post-copy checksum summary
- exportable session log

### 4. Backup-Friendly Workflows

Goal:

- give users a safe workflow for project backup and archive migration

Possible design:

- one-way mirror sync
- append-only archive mode
- exclude rules
- dry-run before execution

## Product Principle

These are advanced features.

They must not weaken the base MountGuard promise:

- safe by default
- explicit before destructive
- checksum when trust matters
- resumable instead of restart-from-zero
- no writes outside user-approved targets
