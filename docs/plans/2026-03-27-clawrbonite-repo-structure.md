# Proposed Clawrbonite Repository Structure

## Purpose

This note proposes a clearer long-term structure for `clawrbonite` so the repo
can separate operational tooling, operator-facing docs, and design records
without blurring the boundary with the `carbonite` archive repo.

## Design Goals

- keep shell tooling easy to find and safe to edit
- make operator docs discoverable without mixing them with working notes
- give decision and plan documents a stable home
- leave room for archive-contract metadata owned by `clawrbonite`
- prefer a low-risk cleanup path over a broad churn-heavy reorganization

## Recommended Top-Level Layout

```text
clawrbonite/
  README.md
  AGENTS.md
  scripts/
    carbonite-init.sh
    carbonite-restore.sh
    carbonite-cron-setup.sh
    carbonite-backup.sh
    carbonite-bundle.sh
    env-setup.sh
  docs/
    operations/
      backup-deployment-guide.md
    decisions/
      2026-03-27-clawrbonite-carbonite-boundary.md
      2026-03-27-carbonite-archive-contract.md
    plans/
      2026-03-26-carbonite-restore-upload.md
      2026-03-26-carbonite-restore-upload-design.md
      2026-03-27-clawrbonite-repo-structure.md
  schema/
    carbonite-manifest-v1.json
```

## Area Responsibilities

### `scripts/`

Holds the executable Carbonite tooling.

- host-side scripts
- sandbox-side scripts
- utility scripts used by backup or bundle flows

This should remain the operational center of the repo.

### `docs/operations/`

Holds operator-facing runbooks and workflow documentation.

- deployment guide
- restore drills
- setup instructions

These docs describe how to use the tooling, not how the repo was designed.

### `docs/decisions/`

Holds durable architecture and contract decisions.

- repo/archive boundary decisions
- archive manifest and compatibility rules
- future ADR-style notes if needed

These should be relatively stable references, not active implementation scratch
space.

### `docs/plans/`

Holds implementation plans and design notes tied to in-flight work.

- issue-specific plans
- migration sketches
- design writeups that may later harden into decisions

This keeps transient planning material separate from stable operator docs.

### `schema/`

Reserved for machine-readable contract artifacts owned by `clawrbonite`.

- manifest schema examples
- future archive validation fixtures

This should only exist once there is a real schema or reference artifact worth
tracking in-repo.

## Why This Structure Fits The Boundary

- tooling stays in `clawrbonite`
- policy and compatibility definitions stay in `clawrbonite`
- only snapshot instances of archive metadata belong in `carbonite`
- the repo gains a clear distinction between operator docs and design work

## Naming Recommendations

- keep executable scripts in `scripts/` with `carbonite-` prefixes
- prefer lowercase kebab-case for documentation filenames
- reserve date prefixes for plans and decision records that are part of project
  history
- use descriptive filenames over generic names like `notes.md`

## Low-Risk First Cleanup Steps

1. Move `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` to
   `docs/operations/backup-deployment-guide.md`.
2. Move durable decision notes from `docs/plans/` to `docs/decisions/`.
   - Done for the boundary and archive-contract notes created in this epic.
3. Update `README.md` to explain repo purpose and point to key script/doc entry
   points.
4. Update `AGENTS.md` repository layout references to match the new structure.
5. Leave `scripts/` names unchanged to avoid unnecessary operational churn.
6. Defer moving the root deployment guide until the existing in-flight edits to
   that file are settled, to avoid mixing structure cleanup with behavior work.

## Things Not To Change Yet

- do not introduce a package manager or build system
- do not split scripts into multiple nested tooling directories yet
- do not move archive state examples into `carbonite` unless they are true
  snapshot artifacts
- do not rename operator-facing commands unless there is a strong migration need

## Working Decision

Adopt a documentation-first cleanup path.

- Keep `scripts/` as the stable home for Carbonite tooling.
- Introduce clearer separation inside `docs/`.
- Add `schema/` only when a real machine-readable contract is ready.
- Make the first structural changes low-risk and easy to explain to operators.
