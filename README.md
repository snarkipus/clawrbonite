# Clawrbonite

`clawrbonite` is the source-of-truth repository for Carbonite tooling used to
back up and restore ephemeral OpenClaw sandbox state.

## What Lives Here

- `scripts/` - Carbonite tooling, including init, restore, backup, bundle, and
  cron setup scripts
- `docs/decisions/` - durable architecture and archive-contract decisions
- `docs/plans/` - in-flight implementation plans and design notes
- `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` - current operator deployment and
  restore guide

## Relationship To `carbonite`

- `clawrbonite` owns tooling, behavior, and archive-format policy
- `carbonite` owns captured sandbox state and per-snapshot archive metadata

## Key Entry Points

- `scripts/carbonite-init.sh`
- `scripts/carbonite-restore.sh`
- `scripts/carbonite-backup.sh`
- `scripts/carbonite-bundle.sh`
- `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md`
- `docs/decisions/2026-03-27-clawrbonite-carbonite-boundary.md`
- `docs/decisions/2026-03-27-carbonite-archive-contract.md`
