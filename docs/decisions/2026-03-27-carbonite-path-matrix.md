# Carbonite Preserve/Recreate/Exclude Matrix

## Purpose

This note translates the archive-boundary decisions into a path-level policy for
what Carbonite should preserve, recreate, exclude, or treat as diagnostic-only.

It is based on:

- current `clawrbonite` backup/restore behavior
- NemoClaw `onboard` code inspection
- the decision that Carbonite should preserve continuity-critical OpenClaw state
  without becoming a migration or platform-bootstrap archive

## Policy Summary

Carbonite should archive only the minimum sandbox state needed to preserve an
OpenClaw assistant across sandbox rebuilds.

- Preserve continuity-critical OpenClaw state.
- Recreate reproducible NemoClaw/OpenShell/bootstrap state.
- Exclude secrets, caches, and host-specific artifacts.
- Treat upstream version metadata as diagnostic context, not restore inputs.

## Path Matrix

| Path or category | Classification | Reason |
|---|---|---|
| `.openclaw/agents/` session/state data | preserve | Core assistant continuity state |
| `.openclaw/agents/*/sessions/` | preserve | Conversation/session continuity |
| Opaque but generic OpenClaw runtime state under `.openclaw/agents/` or `.openclaw-data/` that supports normal operation | preserve | Preserve when it appears to be assistant/runtime continuity state rather than bootstrap or secrets |
| `.openclaw/workspace/` user content | preserve | Primary user/agent workspace content |
| `.openclaw-data/workspace/` | preserve | Backing writable workspace state; may be canonical behind symlinks |
| `.openclaw/cron/` or `.openclaw-data/cron/` | preserve | Scheduled jobs are part of assistant continuity |
| `.openclaw/memory/*.sqlite` | recreate | Rebuildable local memory-search index; continuity survives from workspace/session state and the DB can be regenerated |
| `.openclaw-data/agents/*/agent/models.json` | preserve | Generic runtime model metadata for the routed provider view; observed content is not secret-bearing |
| Nested workspace `.git` history via `.carbonite.bundle*` | preserve | Needed to reconstruct OpenClaw-managed repos |
| Durable user-authored workspace docs such as `SOUL.md`, `AGENTS.md`, `IDENTITY.md`, `USER.md`, `MEMORY.md` | preserve | Assistant behavior/state, not platform bootstrap |
| `.openclaw/openclaw.json` | recreate | Version-specific runtime/bootstrap config; not stable continuity state |
| `.openclaw/.config-hash` | recreate | Derived bootstrap/runtime artifact |
| `.nemoclaw/` inside sandbox | recreate | NemoClaw onboarding/bootstrap metadata |
| Host `~/.nemoclaw/` state | recreate | Host-side control-plane state, outside Carbonite archive scope |
| OpenShell gateway/provider/policy objects | recreate | Platform wiring managed by onboard/init flows |
| Network policy entries and gateway container patches | recreate | Host/platform concerns, not sandbox continuity state |
| `~/carbonite/` sandbox helper scripts and wrappers | preserve | Carbonite tooling and adjacent sandbox helpers belong together as part of practical operator continuity |
| `~/carbonite/bin/carbonite-backup`, `~/carbonite/bin/carbonite-bundle`, `~/carbonite/bin/env-setup` | preserve | Canonical source remains `clawrbonite`, but preserving installed copies improves restore continuity and keeps existing sandbox workflows intact |
| Downloaded third-party binaries or package-managed tools under `~/carbonite/bin/` | exclude or recreate | Preserve authored helpers, but do not treat easily reprovisioned binaries as continuity state by default |
| `~/.bashrc`, `~/.profile`, `~/.gitconfig` intentional sandbox customizations | preserve | Shell and git behavior may be required for the restored sandbox to behave as the operator expects |
| `skills/`, `.clawhub/`, package installs, downloaded binaries | exclude | Reproducible and often version-specific |
| `.git-credentials`, identity files, auth profiles, device auth tokens | exclude | Secrets and auth state |
| `.openclaw/identity/`, `.openclaw-data/identity/`, `.openclaw-data/devices/` | exclude | Sensitive device/auth state |
| `.openclaw-data/update-check.json` | exclude | Update bookkeeping, not continuity state |
| `.openclaw/cache/`, `snapshots/`, `completions/`, npm/cache directories | exclude | Large transient caches |
| Logs, temp files, forwarded ports, running processes | diagnostic-only | Useful for troubleshooting, not for archive restore |
| OpenClaw/OpenShell/NemoClaw version metadata | diagnostic-only | Helpful for restore diagnostics, not contract input |

## Important Boundary Clarifications

### Preserve OpenClaw continuity, not platform shape

The archive should preserve the assistant's durable state, not every file created
by `nemoclaw onboard` or later sandbox customization.

### Do not archive the tool that produced the archive

Carbonite utility scripts are source-controlled in `clawrbonite` and installed by
bootstrap. Even so, preserving installed sandbox copies is acceptable when it
improves restore continuity; `clawrbonite` remains the canonical editing source.

### Do not promise state-shape migration

If upstream changes the shape of OpenClaw state incompatibly, Carbonite should
not silently transform old archives during a normal restore.

### Some re-pairing may still be required

Carbonite should document that a restored sandbox may still require some level
of re-pairing or host-side reattachment to become fully operational again.

Examples include:

- reapplying NemoClaw/OpenShell policy presets or approvals
- reconnecting auxiliary services managed outside the sandbox
- re-establishing host-side provider, gateway, or bridge state

The archive goal is continuity of compatible assistant state, not zero-touch
reconstruction of every integration.

### Preserve opaque operational state carefully

Some operational continuity may depend on opaque OpenClaw state whose meaning is
not fully documented upstream.

Working rule:

- if opaque state lives under the OpenClaw-managed state roots and appears to be
  generic assistant runtime state, preserve it unless there is evidence that it
  is secret material, host bootstrap metadata, or a version-specific generated
  artifact
- if opaque state is clearly a token store, pairing secret, or host/platform
  control-plane artifact, exclude or recreate it instead

## Runtime Validation Notes

Observed in a disposable `nemoclaw onboard` sandbox:

- `.openclaw/*` is largely a symlink facade over `.openclaw-data/*`
- `.nemoclaw/config.json` stores onboarding/provider selection metadata and is
  bootstrap state, not continuity state
- `.openclaw/.config-hash` tracks `openclaw.json` and is derived runtime config
- `.openclaw-data/agents/main/agent/models.json` contains routed provider model
  metadata and appears generic enough to preserve
- `.openclaw-data/identity/device.json` and `.openclaw-data/devices/` exist even
  in a fresh onboarded sandbox and should remain excluded as device/auth state
- `.openclaw/logs/` may be unreadable to the sandbox user and should remain out
  of archive scope
- the sampled archive shows sandbox helper directories, `.bashrc`, and
  `.gitconfig` carrying
  meaningful sandbox-side workflow customizations, so they should be preserved
  unless narrowed by a future allowlist

## Comparison To Current Backup Behavior

Current backup behavior is still broader than this target policy.

Today, `carbonite-backup` stages the whole sandbox home via `git add -A`, and
`carbonite-init.sh` writes a `.gitignore` that excludes some secrets and caches.
That means Carbonite likely still captures several paths that should be
recreated or excluded instead of preserved.

Likely mismatches:

- Carbonite helper scripts should live under `~/carbonite/`; preserve them, but
  consider an allowlist later if downloaded binaries begin to mix into
  `~/carbonite/bin/`
- `~/.bashrc` and related shell/git config are currently backed up; this now
  aligns with the policy when those files contain intentional sandbox
  customizations rather than pure bootstrap defaults
- `.openclaw/openclaw.json` and `.openclaw/.config-hash` appear eligible for
  capture today, but should be treated as recreate
- `.nemoclaw/` is not currently excluded and should be treated as recreate or
  exclude, depending on exact contents
- `.openclaw-data/identity/` and `.openclaw-data/devices/` need explicit review
  and likely exclusion
- some opaque integration-supporting state under `.openclaw/agents/` or
  `.openclaw-data/` may need to remain preserved even if a full integration
  re-pair is still required

## Recommended Follow-Up

1. Narrow Carbonite backup from broad home-directory capture toward an explicit
   allowlist of preserved continuity paths.
2. Add explicit excludes for bootstrap/runtime config such as
   `.openclaw/openclaw.json`, `.openclaw/.config-hash`, and `.nemoclaw/`.
3. Add an allowlist or review rule for `~/carbonite/bin/` if downloaded third-party
   binaries start mixing with authored helper scripts.
4. Keep only coarse upstream version metadata in the manifest for diagnostics.
5. Validate the matrix against a disposable onboarded sandbox before changing
   restore behavior.

## Working Decision

Adopt a continuity-only archive policy.

- Carbonite preserves durable OpenClaw assistant state.
- Carbonite does not preserve version-specific platform/bootstrap state by
  default.
- Carbonite does not imply migration support across breaking upstream state
  changes.
