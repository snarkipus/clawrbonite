# Carbonite Backup — Deployment Guide
## For NemoClaw/OpenShell/OpenClaw sandbox on Hetzner CX33

---

## Overview

Carbonite is a git-based backup system for the ephemeral OpenClaw sandbox. It
preserves continuity-critical OpenClaw state (identity, sessions, workspace,
memories, and creative output) across the
frequent tear-down/rebuild cycles driven by alpha-era NemoClaw and OpenShell
commit velocity.

Carbonite does **NOT** protect against pod restarts transparently — after a
rebuild, you restore from the last backup into a clean sandbox.

### Design Assumptions

- Sandbox is disposable — restore targets a **clean post-creation sandbox**
- Rebuilds are frequent (near-daily during alpha)
- During upstream alpha churn, prefer full teardown + fresh `nemoclaw onboard`
  before Carbonite restore rather than trying to repair a drifted runtime in
  place
- Host-side patches (fetch-guard, openclaw.json, network policy) are outside
  Carbonite's scope — those require Priority 2 (custom image) to persist
- Some re-pairing or host-side reattachment may still be required after restore
- GitHub CLI auth is a hard runtime dependency for Carbonite operations
- Sandbox GitHub HTTPS may run through OpenShell TLS termination; when
  `/etc/openshell-tls/openshell-ca.pem` is present, sandbox `git` should trust
  that CA for `github.com`
- Current NemoClaw sandboxes use the canonical mutable `~/.openclaw` root for
  assistant state; Carbonite should keep its writable repo/helpers under
  `~/.openclaw`

### Bundle Architecture

OpenClaw manages internal git repos (e.g., `~/.openclaw/workspace/` containing
SOUL.md, AGENTS.md, etc.). Git refuses to `git add` directories containing nested
`.git` dirs. Carbonite solves this with a freeze/thaw cycle using `git bundle`:

```
BACKUP (freeze):
  Nested .git dirs → git bundle create → .carbonite.bundle files
  .gitignore excludes **/.git
  git add -A picks up .bundle files + all workspace content files

RESTORE (thaw):
  .carbonite.bundle files → git init + fetch into tracking refs + checkout + reset --hard
  Post-thaw validation: rev-parse, symbolic-ref, status, last commit message
```

### Resilience Features

- **Locking:** `flock` prevents concurrent backup runs (cron + manual overlap)
- **Commit/push separation:** Local commit always succeeds; push failure is
  non-fatal and retried on next run
- **Unpushed commit detection:** If previous push failed, next run detects
  and retries before checking for new changes
- **Post-thaw validation:** Each restored nested repo is verified with
  `rev-parse --is-inside-work-tree`, `symbolic-ref HEAD`, `status --porcelain`
- **Idempotent cron:** Setup script checks for existing job before creating

---

## What's Backed Up

- `.openclaw/agents/` — agent runtime state, sessions, and continuity-bearing
  assistant history
- `.openclaw/workspace/` — SOUL.md, AGENTS.md, DREAMS.md, HEARTBEAT.md,
  IDENTITY.md, USER.md, MEMORY.md, daily memory notes, dream corpus/diary
  artifacts, and other user-authored workspace files
- `.openclaw/canvas/`, `hooks/`, `media/`, and `skills/` — creative,
  assistant-authored, or markdown-based instruction content when present
- `.carbonite.bundle` files — frozen snapshots of nested git repo state

## What's Excluded

- All nested `.git` directories (archived as `.carbonite.bundle` instead)
- Credentials (`identity/`, `auth-profiles.json`)
- Device/pairing state (`.openclaw/devices/`, `.openclaw/identity/`)
- `.openclaw/credentials/` — runtime credential store and provider wiring
- `.openclaw/exec-approvals.json` — operational approval state, not
  assistant continuity
- `.openclaw/npm/` — generated runtime install state
- `.openclaw/completions/` — reproducible shell completion artifacts
- `.openclaw/backups/` — operator repair snapshots, not continuity state
- `.openclaw/carbonite/` — restore-control tooling now comes from the trusted
  local `clawrbonite` checkout via helper overlay, not from archived copies
- archived helper CLIs such as `websearch` or `ghwatch` should be treated the
  same way: reprovision from the current trusted `clawrbonite` checkout once
  validated for the current runtime shape, rather than preserved as archive-owned
  continuity content
- `.openclaw/cron/` — scheduler definitions and run state are operational
  substrate rather than the assistant's essence
- replaying restored `.openclaw/cron/jobs.json` is not sufficient to recreate a
  live working OpenClaw cron schedule in a fresh runtime; re-register required
  jobs such as the Carbonite backup job from the current helper set instead of
  treating cron metadata as archive-owned continuity state
- `.openclaw/flows/` — operational registry state, not durable creative output
- `.openclaw/memory/main.sqlite` — rebuildable memory/runtime DB state
- `.openclaw/plugins/` — plugin install bookkeeping is runtime substrate and
  collides with healthy live runtimes
- `.openclaw/qmd/`, `.openclaw/sandbox/`, `.openclaw/session-delivery-queue/`,
  `.openclaw/tasks/`, and `.openclaw/telegram/` — runtime,
  transport, or execution substrate rather than conversation/content continuity
- `.openclaw/agents/*/sessions/*.bak-*` — repair/forensic session backups stay
  out of the normal portable archive
- `.openclaw/wiki/main/**` — wiki document content is sync-owned elsewhere and
  should not be restored from Carbonite
- `.openclaw/workspace/memory/agentmail-last-check.json`,
  `heartbeat-state.json`, `rss-state/**`, `rsshub-upstream-state.json`, and
  `wiki-watch/**` — operational cursor/checkpoint state rather than durable
  continuity content
- `.openclaw/agents/*/qmd/xdg-cache/` and `xdg-config/` — QMD runtime
  cache, index, and downloaded embedding model artifacts; reproducible and too
  large/noisy for the Carbonite archive
- `.openclaw/logs/` — runtime diagnostics, not continuity state
- `.openclaw/openclaw.json.bak-*` — host-side config patch residue
- Bootstrap/runtime config (`.nemoclaw/`, `.openclaw/openclaw.json`,
  `.openclaw/.config-hash`)
- Top-level home dotfiles and scaffold files (`.bashrc`, `.profile`,
  `.gitconfig`, `.workspace-initialized`)
- Shell history (`.bash_history`)
- npm packages (`.npm-global/`, `node_modules/`)
- Caches (`.openclaw/cache/`, `completions/`, `snapshots/`)
- Update bookkeeping (`.openclaw/update-check.json`)
- Chromium / browser artifacts
- Carbonite lock file (`.carbonite.lock`)
- Carbonite local env helpers (`.openclaw/carbonite/env.sh`) and any
  legacy auth helper files from older Carbonite layouts

---

## Fresh Sandbox Setup (first time ever)

### Step 1: Upload scripts to sandbox

```bash
openshell sandbox upload my-assistant ./scripts/carbonite-init.sh /sandbox/.openclaw/carbonite/carbonite-init.sh
openshell sandbox upload my-assistant ./scripts/carbonite-cron-setup.sh /sandbox/.openclaw/carbonite/carbonite-cron-setup.sh
```

### Step 2: Run initialization

Inside the sandbox (`nemoclaw my-assistant connect`):

```bash
bash ~/.openclaw/carbonite/carbonite-init.sh
```

This requires a working sandbox `gh auth status` backed by the runtime GitHub
credential provider.

Disposable validation against a scratch archive repo:

```bash
CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
  bash ~/.openclaw/carbonite/carbonite-init.sh
```

### Step 3: Set up scheduled backups

```bash
bash ~/.openclaw/carbonite/carbonite-cron-setup.sh
```

### Step 4: Verify

```bash
~/.openclaw/carbonite/bin/carbonite-bundle status      # show nested repos and bundles
~/.openclaw/carbonite/bin/carbonite-backup "test: initial"  # manual test
git log --oneline -5                 # check commits
openclaw cron list                   # check cron registration
```

---

## Restoring After Catastrophic Sandbox State Loss

**Precondition:** Restore targets a clean, freshly created sandbox.

This restore flow applies whenever the ephemeral OpenClaw sandbox state has been
effectively lost and you have a sane host-side NemoClaw/OpenShell plus a fresh
replacement sandbox target.

Common causes include:

- intentional teardown followed by fresh `nemoclaw onboard`
- a rebuild or reprovision of the sandbox/runtime substrate
- an OpenShell gateway replacement or rebootstrap event that unexpectedly pulls
  a fresh runtime image or leaves the old ephemeral OpenClaw state unavailable

**Important:** Carbonite restores continuity data, not a complete OpenClaw
runtime bootstrap. The recommended alpha-era recovery path is:

1. tear down the old disposable sandbox
2. run fresh `nemoclaw onboard` to scaffold the new sandbox/runtime
3. restore the Carbonite archive into that clean sandbox
4. run `~/.openclaw/carbonite/carbonite-init.sh --continue --no-push`
5. reapply any required host-side/runtime patches

Do not assume a raw Carbonite restore alone will make `openclaw` immediately
functional in a brand new sandbox; excluded runtime/bootstrap files such as
`~/.openclaw/openclaw.json`, pairing state, and gateway bootstrap state still
need to come from the fresh onboarded environment.

In other words, the principal cause of the loss event does not materially change
the Carbonite restore mechanics. What matters is that restore starts from a
clean sandbox attached to a sane host-side NemoClaw/OpenShell environment.

### Archive layout note for older Carbonite snapshots

- Older Carbonite archives may still be shaped around top-level `/sandbox`
  home writes, with paths such as `.openclaw-data/...` plus sibling
  `carbonite/`, `.bashrc`, and `.profile` entries at archive root.
- Current NemoClaw runtimes are a better fit for a repo root at
  `~/.openclaw`, with `carbonite/` living under that writable root.
- Before restoring an older archive into the newer runtime model, do a one-time
  archive reshape in the checked-out archive repo:
  - hoist the contents of `.openclaw-data/` to archive root
  - keep `carbonite/` at archive root so it restores to `~/.openclaw/carbonite`
  - drop top-level `.bashrc`, `.profile`, and similar home-root assumptions that
    no longer map to writable continuity state
  - refresh `.gitignore` and the bundled helper scripts from `clawrbonite`

### On the host:

```bash
bash carbonite-restore.sh my-assistant
```

Use the same override if restoring from a scratch archive:

```bash
CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
  bash carbonite-restore.sh my-assistant
```

### Inside the new sandbox:

```bash
# Extract the uploaded restore archive into the writable Carbonite repo root
mkdir -p ~/.openclaw
tar -xf /tmp/carbonite-restore-upload/carbonite-restore.tar -C ~/.openclaw

# Overwrite archived restore-control helpers with the current trusted versions
tar -xf /tmp/carbonite-restore-upload/carbonite-restore-helpers.tar -C ~/.openclaw

# Re-init with history preservation + thaw + validation, but no archive writeback yet
bash ~/.openclaw/carbonite/carbonite-init.sh --continue --no-push

# Re-register cron job (idempotent — safe to re-run)
bash ~/.openclaw/carbonite/carbonite-cron-setup.sh

# Recreate excluded env template if needed
bash ~/.openclaw/carbonite/bin/env-setup

# Verify
~/.openclaw/carbonite/bin/carbonite-bundle status
git -C ~/.openclaw/workspace rev-parse --is-inside-work-tree || true
~/.openclaw/carbonite/bin/carbonite-backup 'post-restore verification'
openclaw memory status --deep
```

Important cron note:

- do not rely on restored `.openclaw/cron/**` files alone as proof that the
  active OpenClaw scheduler has the intended jobs
- validate with `openclaw cron list`
- if the backup cron is missing, re-run
  `bash ~/.openclaw/carbonite/carbonite-cron-setup.sh` once the sandbox-local
  gateway is healthy

For sacrificial restore validation, do not allow `--continue` to create or push
an archive commit before you verify the restored state. The host restore helper
now uploads a trusted current helper overlay specifically so restore control does
not depend on stale archived `carbonite/` scripts.

This same policy should be used for operator-approved helper CLIs that are not
part of the assistant's continuity state. If helpers such as `websearch` are
needed after restore, prefer to ship them from the current `clawrbonite`
checkout/helper overlay after validating their runtime assumptions, rather than
bringing them back as Carbonite-owned archive payload.

Current trusted reprovisioned helper set includes:

- `~/.openclaw/carbonite/bin/carbonite-backup`
- `~/.openclaw/carbonite/bin/carbonite-bundle`
- `~/.openclaw/carbonite/bin/env-setup`
- `~/.openclaw/carbonite/bin/websearch`

`websearch` is a small Bash CLI that queries the OpenShell-hosted SearXNG
sidecar, defaulting to `SEARXNG_URL=http://host.openshell.internal:8888`.

On a brand new sacrificial sandbox, the first `--continue` attempt may still hit
a GitHub network approval gate before the history clone succeeds. If that first
attempt fails before `.git` is materialized in `~/.openclaw`, approve the
network request and retry in the same fresh sandbox. If a partial `.git` already
exists, discard the sandbox and retry only from a new fresh target.

Validated sacrificial restore outcome on `2026-05-04` against fresh
`my-assistant-v12`:

- canonical `.openclaw` restore succeeded with `Missing after restore: 0`
- trusted helper overlay prevented stale `.openclaw-data` restore logic from
  running
- `workspace/.carbonite.bundle.tar` thawed successfully back into a usable
  nested workspace repo
- `wiki/main/**` was absent after restore, matching the new exclusion policy
- the remaining post-restore gaps were runtime/config replay issues rather than
  Carbonite archive loss

Validated scratch essence-only archive outcome later on `2026-05-04` against a
fresh recreated `my-assistant-v12` using
`CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git`:

- `carbonite-init.sh --continue --no-push` cloned scratch history successfully
- restore integrity reported `Tracked files in last backup: 424`,
  `Missing after restore: 0`, and `Modified after restore: 0`
- no staged deletions remained for excluded runtime substrate such as `cron/`,
  `flows/`, `memory/main.sqlite`, `tasks/`, `telegram/`, or archived helper
  payloads
- the scratch validation is the current strongest proof of the refined
  essence-only Carbonite contract

### Post-restore QMD rebuild

Carbonite intentionally excludes QMD runtime cache/model artifacts from backup:

- `~/.openclaw/agents/*/qmd/xdg-cache/`
- `~/.openclaw/agents/*/qmd/xdg-config/`

That means a restore brings back the source content (`MEMORY.md`, daily memory
notes, wiki files, cron state), but not a ready-to-use QMD runtime index.

Operational expectation after restore:

- QMD may have zero/stale collections until rebuilt
- the local embedding model may be downloaded again on first rebuild
- direct/shared search can remain incomplete until reindex finishes

Treat QMD rebuild/reindex as part of restore validation. After the restored
workspace/wiki content is in place, verify memory status and rebuild QMD if the
index is empty, stale, or missing expected collections. Record that rebuild in
handoff notes when it was required.

### Host-side patches still needed (until Priority 2 custom image):

1. **Fetch-guard patch** — `docker exec` sed commands (session notes Step 3)
2. **openclaw.json web config** — `docker cp` (session notes Step 4)
3. **Network policy** — `openshell policy set` (session notes Step 5)
4. **Gateway restart inside sandbox** — kill old process, `openclaw gateway &`

### GitHub TLS trust inside the sandbox

- OpenShell may terminate outbound GitHub HTTPS at the sandbox egress proxy and
  re-sign the connection with `/etc/openshell-tls/openshell-ca.pem`.
- If sandbox `git` reports x509 or `CAfile: none` failures to `github.com`, set
  trust explicitly before retrying push/clone:

```bash
export GIT_SSL_CAINFO=/etc/openshell-tls/openshell-ca.pem
git config --global http.https://github.com/.sslCAInfo /etc/openshell-tls/openshell-ca.pem
```

- `carbonite-init.sh` now applies that GitHub-scoped setting automatically when
  the OpenShell CA file exists, then runs `gh auth setup-git` so git transport
  uses the authenticated GitHub CLI credential helper.
- For clone/fetch/push, both `gh` and `git` still need a loaded GitHub policy
  that permits the relevant GitHub traffic.
- If provider-backed git transport to `github.com` is still broken, Carbonite
  can fall back to a real sandbox-local `GITHUB_TOKEN` exported from
  `~/.openclaw/carbonite/env.sh`. Carbonite converts that token into a
  one-shot Basic auth header for git operations without storing it in git
  config. Keep that token untracked, repo-scoped, and temporary.
- Only fall back to a repo-scoped `sslVerify=false` override for disposable
  scratch validation. Do **not** normalize a global `http.sslVerify=false`
  setting as the default recovery path.

### What restore proves vs. what it does not

- Restore **does** preserve continuity artifacts such as session transcripts,
  workspace memory notes, identity/workspace content, and nested workspace repo
  contents.
- Restore **does not** by itself recreate the full excluded runtime/bootstrap
  layer needed for OpenClaw to attach to that data in a fresh sandbox.
- If restored files are present but `openclaw status --deep` or
  `openclaw agent` still fail, treat that as runtime/bootstrap drift rather than
  archive loss.

---

## Manual Operations

```bash
~/.openclaw/carbonite/bin/carbonite-backup                         # incremental backup
~/.openclaw/carbonite/bin/carbonite-backup "pre-upgrade snapshot"  # custom message
~/.openclaw/carbonite/bin/carbonite-bundle status                  # show nested repos & bundles
~/.openclaw/carbonite/bin/carbonite-bundle freeze                  # manually freeze nested repos
~/.openclaw/carbonite/bin/carbonite-bundle thaw                    # restore .git dirs from bundles
```

---

## Cron Job Reference

| Field | Value |
|-------|-------|
| Name | Carbonite backup |
| Schedule | `0 0,12 * * *` (12:00 AM and 12:00 PM ET) |
| Timezone | America/New_York |
| Session | isolated (light context) |
| Storage | `~/.openclaw/cron/jobs.json` |
| Survives | Gateway restart ✓, Sandbox rebuild ✗ |

---

## Limitations

1. **Not real-time** — 4-hour backup interval. Data between backups and a crash is lost.
2. **No transparent restore** — Manual restore + init required after rebuild.
3. **Fresh onboard still required** — Carbonite is not a full substitute for
   `nemoclaw onboard` during upstream runtime churn.
4. **Host-side patches not covered** — Container overlay changes are out of scope.
5. **Git push requires network policy** — `github` policy entry must be present.
6. **Session data may grow** — Monitor with `du -sh ~/.openclaw/agents/main/sessions/`.
7. **Bundle thaw is non-standard** — Post-thaw validation checks for sanity but cannot
   guarantee OpenClaw will behave identically to pre-backup state. Monitor for issues
   across rebuild cycles.
8. **GitHub auth is required** — Carbonite expects either a working `gh auth status`
   in the sandbox or a local `GITHUB_TOKEN` fallback in
   `~/.openclaw/carbonite/env.sh`.
9. **Sandbox Git TLS depends on proxy CA trust** — If GitHub HTTPS is
   TLS-terminated by OpenShell, sandbox `git` must trust
   `/etc/openshell-tls/openshell-ca.pem`.

---

## File Inventory

| File | Location | Purpose |
|------|----------|---------|
| `carbonite/carbonite-init.sh` | `~/.openclaw/carbonite/` | One-time setup or `--continue` after restore |
| `carbonite/carbonite-cron-setup.sh` | `~/.openclaw/carbonite/` | Register scheduled backup during fresh setup or after restore |
| `carbonite/bin/carbonite-backup` | `~/.openclaw/carbonite/bin/` | Incremental backup with auto-freeze + lock |
| `carbonite/bin/carbonite-bundle` | `~/.openclaw/carbonite/bin/` | Freeze/thaw nested git repos |
| `carbonite/bin/websearch` | `~/.openclaw/carbonite/bin/` | Trusted SearXNG sidecar query helper reprovisioned from `clawrbonite` |
| `carbonite/bin/env-setup` | `~/.openclaw/carbonite/bin/` | Recreate a local env helper after rebuild |
| `carbonite-restore.sh` | Host only | Restore sandbox from GitHub backup |
| `.gitignore` | `~/.openclaw/` (written by init) | Exclusion rules |
| `.carbonite.bundle` | Next to each nested `.git` | Frozen git repo snapshot |
| `.carbonite.lock` | `~/.openclaw/` (runtime) | Prevents concurrent backups |
