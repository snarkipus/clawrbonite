# Carbonite Archive Manifest Contract

## Purpose

This note defines the minimum manifest contract between `clawrbonite` tooling and
the `carbonite` archive repository.

The goal is to keep archive snapshots self-describing enough to support restore
decisions, compatibility checks, and later format evolution without turning the
archive repo into a second tooling repo.

In practice, the manifest will likely be written by the backup-side utility flow
(`carbonite-backup`, with bundle metadata sourced from `carbonite-bundle`) and
read by restore/init flows during rebuild recovery.

## Contract Scope

The contract covers:

- the intended scope of preserved OpenClaw state versus reproducible tooling or
  platform configuration
- the minimum metadata each archive snapshot should carry
- which fields are required versus optional
- how archive format changes should be versioned
- what compatibility expectations `clawrbonite` should honor when restoring

The contract does not require implementation immediately, but future archive and
restore changes should conform to it.

For the current path-level preserve/recreate/exclude policy, see
`docs/decisions/2026-03-27-carbonite-path-matrix.md`.

## Archive Scope

The `carbonite` archive should preserve only the minimum OpenClaw sandbox state
needed for continuity across rebuilds.

Primary examples:

- OpenClaw agent state and sessions
- OpenClaw workspace content
- OpenClaw cron/job definitions
- frozen nested-repo state needed to reconstruct workspace git repos
- small operator-managed shell customizations that are part of the sandbox state

The archive should not become a general snapshot of version-specific platform
setup around NemoClaw, OpenShell, or host bootstrap flows.

This does not exclude intentional sandbox-side helper scripts or shell/git
customizations when they are part of the operator's day-to-day workflow inside
the sandbox. Those may still be preserved as continuity state even if their
canonical source lives elsewhere.

## Explicit Exclusions By Intent

Do not treat these categories as durable archive contract inputs unless a later
decision explicitly opts them in:

- NemoClaw version-specific manifests or generated config
- OpenShell or gateway bootstrap scripts that can be reprovisioned
- host-specific patches, policies, or deployment wiring
- transient caches, package installs, and downloaded tooling
- compatibility shims added only to bridge one upstream release to another

If something is reproducible from current tooling or from the base environment,
prefer to recreate it during init/restore rather than version it inside the
archive.

## Manifest Placement

Each backup snapshot in `carbonite` should include one manifest instance written
by `clawrbonite`.

Preferred path:

- `.carbonite-manifest.json`

This keeps the metadata easy to inspect during restore debugging and makes it
clear that the manifest is archive state, while the schema and policy remain in
`clawrbonite`.

## Required Fields

Each manifest instance should contain at least:

- `manifest_version`
  - integer format version for the manifest schema itself
- `created_at`
  - UTC timestamp in ISO 8601 format
- `archive_kind`
  - string value identifying this as a Carbonite sandbox-state archive
- `tool`
  - object naming the producing tool
- `tool.name`
  - fixed value: `clawrbonite`
- `tool.version_ref`
  - git tag, version string, or commit SHA for the producing tooling revision
- `archive`
  - object describing the captured snapshot
- `archive.layout_version`
  - integer version for the on-disk archive layout and restore expectations
- `archive.clean_restore_required`
  - boolean indicating whether restore assumes a fresh sandbox target

## Recommended Fields

These are not required for the first implementation, but should be added when
easy to capture safely:

- `archive.nested_repo_bundle_format`
  - string or integer describing the bundle/freeze strategy in use
- `archive.includes`
  - list of top-level inclusion categories or paths
- `archive.excludes`
  - list of exclusion categories or paths
- `environment`
  - object describing the source environment at a coarse level for diagnostics
- `environment.platform`
  - host/sandbox platform identifier if useful
- `environment.openshell_version`
  - OpenShell version if known, for debugging only
- `environment.openclaw_version`
  - OpenClaw version if known, for debugging only

Environment fields are advisory metadata, not restore contract inputs. Restore
logic should not silently depend on exact upstream version matches unless a
future decision explicitly introduces that requirement.

## Example Shape

```json
{
  "manifest_version": 1,
  "created_at": "2026-03-27T14:00:00Z",
  "archive_kind": "carbonite-openclaw-sandbox-state",
  "tool": {
    "name": "clawrbonite",
    "version_ref": "main@abc1234"
  },
  "archive": {
    "layout_version": 1,
    "clean_restore_required": true,
    "nested_repo_bundle_format": 1,
    "includes": [
      ".openclaw/agents",
      ".openclaw/workspace",
      ".openclaw/cron",
      "bin"
    ],
    "excludes": [
      "**/.git",
      ".git-credentials",
      ".bash_history"
    ]
  },
  "environment": {
    "openshell_version": "0.0.10"
  }
}
```

## Versioning Rules

Use two separate version numbers.

### `manifest_version`

This version changes when the schema of `.carbonite-manifest.json` changes.

- Increment for required field additions, removals, or semantic changes
- Do not increment for archive-content changes that leave the manifest schema
  unchanged

### `archive.layout_version`

This version changes when the archive contents or restore assumptions change in a
way that affects restore behavior.

Examples:

- moving manifest location
- changing bundle storage conventions
- changing required restore preconditions
- changing the expected placement of restored files

This lets `clawrbonite` distinguish schema changes from restore-layout changes.

## Compatibility Policy

Current working policy:

- Newer `clawrbonite` should try to restore older archive layout versions when
  feasible
- Restore must fail loudly when the archive layout version is unknown or known
  incompatible
- Missing recommended fields should not block restore
- Missing required fields should block restore once manifest enforcement exists

## Non-Goal: Upstream State Migration

This implementation is for backup and restore of compatible OpenClaw state, not
for general migration across breaking upstream changes.

Specifically, Carbonite should not promise to translate one OpenClaw state shape
into another when upstream NemoClaw, OpenShell, or OpenClaw releases make
breaking changes to the underlying stored data.

If upstream state shape changes incompatibly, the correct response is one of:

- declare the older archive layout unsupported for the newer restore flow
- add an explicit, reviewed migration step as a separate scoped feature
- narrow the archived state so only stable continuity data is preserved

It should not happen implicitly during ordinary restore.

## Operational Restore Caveat

Carbonite restore should be documented as restoring compatible assistant state,
not guaranteeing a fully reattached operational environment with zero manual
follow-up.

Some integrations may still require re-pairing, policy reapplication, or host-
side reattachment after restore.

At the same time, Carbonite should preserve opaque generic OpenClaw continuity
state when it lives under the managed state roots and is not clearly bootstrap
metadata or secret material. This avoids throwing away runtime-supporting state
just because upstream does not document its exact meaning.

## Behavioral Expectations

`clawrbonite` should eventually:

- write a manifest during backup creation
- write it from the backup-side utility flow rather than by hand in the archive
- read and validate the manifest during restore
- print the producing `tool.version_ref` during restore diagnostics
- treat environment version metadata as advisory diagnostics, not as data to
  restore into the archive
- warn clearly when restoring an older supported layout version
- stop with an actionable error for unsupported layout versions

## Change Policy

Any change to required manifest fields or archive layout semantics should be
treated as a contract decision in `clawrbonite`, with corresponding doc updates.

The `carbonite` repo should only store instances of the manifest, not define the
policy.

## Working Decision

Adopt a self-describing archive model.

- `clawrbonite` defines the manifest schema and compatibility rules.
- `carbonite` stores one manifest instance per snapshot.
- Compatibility is based on explicit manifest and layout versions, not implicit
  tribal knowledge.
