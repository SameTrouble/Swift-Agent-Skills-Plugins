# Swift Agent Skills (English)

This directory is the English plugin package. Skills under `skills/` are automatically synced from upstream repositories by `scripts/sync.sh`.

## Syncing

Maintainers run:

```bash
./scripts/sync.sh
```

This reads `scripts/catalog.json`, re-clones each upstream, and copies skill files into `skills/`. Review `git diff` before committing.

## Installation

See the root [README.md](../../README.md) for installation instructions.
