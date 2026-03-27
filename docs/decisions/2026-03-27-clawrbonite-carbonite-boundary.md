# Clawrbonite and Carbonite Boundary Notes

## Purpose

This note records the current intended boundary between `clawrbonite` and
`carbonite`, plus the decision criteria that should guide future placement
choices.

## Current Roles

### `clawrbonite`

`clawrbonite` is the source-of-truth repository for Carbonite tooling.

It should own:

- backup, restore, init, and cron setup scripts
- utility scripts such as `carbonite-backup` and `carbonite-bundle`
- archive layout and restore-flow decisions
- operational documentation and operator runbooks
- archive contract and compatibility rules
- design notes, implementation plans, and follow-up work tracking references

### `carbonite`

`carbonite` is the state archive repository for ephemeral OpenClaw sandbox data.

It should own:

- archived sandbox state produced by Carbonite tooling
- frozen nested-repo bundle payloads and restored workspace contents
- archive metadata needed to understand what produced a snapshot
- commit history representing backup points over time

That archive content should stay focused on OpenClaw continuity state, not on
capturing every version-specific detail of NemoClaw/OpenShell/bootstrap setup.

It should not become a second home for restore logic, archive-policy decisions,
or operational documentation beyond minimal archive-facing metadata.

## Boundary Rule

If a file exists to define, produce, validate, or explain the archive system, it
belongs in `clawrbonite`.

If a file exists because it was captured from the sandbox as state, it belongs
in `carbonite`.

## Decision Criteria

When deciding where something belongs, use these questions in order:

1. Is this file or change executable tooling or documentation for operators?
   - If yes, place it in `clawrbonite`.
2. Is this file part of the sandbox state being preserved across rebuilds?
   - If yes, place it in `carbonite`.
3. Would changing it alter backup or restore behavior for all future archives?
   - If yes, place it in `clawrbonite`.
4. Would changing it only alter the contents of one captured environment state?
   - If yes, place it in `carbonite`.
5. Does it need versioned compatibility promises between tooling and archive
   contents?
   - Define the contract in `clawrbonite`; store only the resulting archive
     metadata in `carbonite`.

## Practical Examples

- `scripts/carbonite-init.sh` belongs in `clawrbonite`.
- `scripts/carbonite-restore.sh` belongs in `clawrbonite`.
- `scripts/carbonite-backup.sh` belongs in `clawrbonite`.
- `scripts/carbonite-bundle.sh` belongs in `clawrbonite`.
- `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` belongs in `clawrbonite`.
- A manifest schema or archive format version definition belongs in
  `clawrbonite`.
- A manifest instance written into a backup snapshot belongs in `carbonite`.
- Restored workspace files, sessions, and bundle payloads belong in `carbonite`.
- A version-specific NemoClaw manifest or bootstrap config that can be
  reprovisioned belongs outside the archive contract unless explicitly promoted
  into supported state.

## Ambiguities To Resolve Later

- What minimum manifest metadata each `carbonite` snapshot should carry about
  the producing `clawrbonite` version
- Whether `clawrbonite` should publish tagged release artifacts for operators to
  use during restore/bootstrap flows
- Whether the current `clawrbonite` repository layout should introduce clearer
  top-level separation between scripts, operational docs, and design records

## Working Decision

Keep the current two-repo model.

- `clawrbonite` remains the only place where Carbonite behavior is edited.
- `carbonite` remains an archive/state repository, not a peer tooling repo.
- `carbonite` should preserve continuity-critical OpenClaw state, not act as a
  migration layer for breaking upstream state-shape changes.
- Any future refactor should make this boundary easier to see, not blur it.
