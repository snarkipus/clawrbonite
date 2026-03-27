# Carbonite Backup — Deployment Guide
## For NemoClaw/OpenShell/OpenClaw sandbox on Hetzner CX33

---

## Overview

Carbonite is a git-based backup system for the ephemeral OpenClaw sandbox. It
preserves continuity-critical OpenClaw state (agent runtime state, sessions,
workspace, memory, cron jobs, and sandbox helper customizations) across the
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
- PAT-based auth is expedient for alpha; rotate regularly
- GitHub TLS trust for sandbox `git` remains unresolved in current validation;
  disposable tests required a repo-scoped `sslVerify=false` override for the
  scratch archive only

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

- `.openclaw-data/agents/` — agent runtime state, `models.json`, sessions,
  `sessions.json`
- `.openclaw-data/workspace/` — SOUL.md, AGENTS.md, IDENTITY.md, USER.md,
  MEMORY.md, daily memory notes, and other user-authored workspace files
- `.openclaw-data/cron/` — scheduled job definitions and run history
- `.openclaw/memory/` — primary SQLite memory databases (not WAL/SHM sidecars)
- `~/carbonite/` — sandbox Carbonite scripts and helper tools, including
  `~/carbonite/bin/`
- `.bashrc`, `.profile`, `.gitconfig` — intentional shell and git customizations
- `.carbonite.bundle` files — frozen snapshots of nested git repo state

## What's Excluded

- All nested `.git` directories (archived as `.carbonite.bundle` instead)
- Credentials (`.git-credentials`, `identity/`, `auth-profiles.json`)
- Device/pairing state (`.openclaw-data/devices/`, `.openclaw-data/identity/`)
- Bootstrap/runtime config (`.nemoclaw/`, `.openclaw/openclaw.json`,
  `.openclaw/.config-hash`)
- Shell history (`.bash_history`)
- npm packages (`.npm-global/`, `node_modules/`)
- Caches (`.openclaw/cache/`, `completions/`, `snapshots/`)
- Update bookkeeping (`.openclaw-data/update-check.json`)
- Skills from clawhub (`skills/` — reproducible via `clawhub install`)
- Chromium / browser artifacts
- Carbonite lock file (`.carbonite.lock`)

---

## Fresh Sandbox Setup (first time ever)

### Step 1: Upload scripts to sandbox

```bash
openshell sandbox upload my-assistant ./scripts/carbonite-init.sh /sandbox/carbonite/carbonite-init.sh
openshell sandbox upload my-assistant ./scripts/carbonite-cron-setup.sh /sandbox/carbonite/carbonite-cron-setup.sh
```

### Step 2: Run initialization

Inside the sandbox (`nemoclaw my-assistant connect`):

```bash
GH_PAT=ghp_your_token_here bash ~/carbonite/carbonite-init.sh
```

Disposable validation against a scratch archive repo:

```bash
CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
  GH_PAT=ghp_your_token_here bash ~/carbonite/carbonite-init.sh
```

### Step 3: Set up scheduled backups

```bash
bash ~/carbonite/carbonite-cron-setup.sh
```

### Step 4: Verify

```bash
carbonite-bundle status              # show nested repos and bundles
carbonite-backup "test: initial"     # manual test
git log --oneline -5                 # check commits
openclaw cron list                   # check cron registration
```

---

## Restoring After a Rebuild

**Precondition:** Restore targets a clean, freshly created sandbox.

**Important:** Carbonite restores continuity data, not a complete OpenClaw
runtime bootstrap. The recommended alpha-era recovery path is:

1. tear down the old disposable sandbox
2. run fresh `nemoclaw onboard` to scaffold the new sandbox/runtime
3. restore the Carbonite archive into that clean sandbox
4. run `~/carbonite/carbonite-init.sh --continue`
5. reapply any required host-side/runtime patches

Do not assume a raw Carbonite restore alone will make `openclaw` immediately
functional in a brand new sandbox; excluded runtime/bootstrap files such as
`~/.openclaw/openclaw.json`, pairing state, and gateway bootstrap state still
need to come from the fresh onboarded environment.

### On the host:

```bash
GH_PAT=ghp_xxx bash carbonite-restore.sh my-assistant
```

Use the same override if restoring from a scratch archive:

```bash
CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
  GH_PAT=ghp_xxx bash carbonite-restore.sh my-assistant
```

### Inside the new sandbox:

```bash
# Extract the uploaded restore archive into sandbox home
tar -xf ~/carbonite-restore.tar -C ~

# Re-init with history preservation + thaw + validation
GH_PAT=ghp_xxx bash ~/carbonite/carbonite-init.sh --continue

# Re-register cron job (idempotent — safe to re-run)
bash ~/carbonite/carbonite-cron-setup.sh

# Recreate excluded env template if needed
bash ~/carbonite/bin/env-setup

# Verify
carbonite-bundle status
carbonite-backup 'post-restore verification'
```

### Host-side patches still needed (until Priority 2 custom image):

1. **Fetch-guard patch** — `docker exec` sed commands (session notes Step 3)
2. **openclaw.json web config** — `docker cp` (session notes Step 4)
3. **Network policy** — `openshell policy set` (session notes Step 5)
4. **Gateway restart inside sandbox** — kill old process, `openclaw gateway &`

### Known unresolved Git/TLS issue

- In current disposable validation, `curl` to GitHub succeeds from the sandbox
  once policy is correct, but sandbox `git` still fails certificate validation.
- Temporary validation workaround used:

```bash
git config http.https://github.com/snarkipus/carbonite-scratch.git.sslVerify false
```

- Keep this repo-scoped and scratch-only. Do **not** normalize a global
  `http.sslVerify=false` setting as the default recovery path.
- Until the TLS root cause is fixed, treat sandbox GitHub push/clone as an
  environment caveat rather than a Carbonite archive-contract failure.

### What restore proves vs. what it does not

- Restore **does** preserve continuity artifacts such as session transcripts,
  workspace memory notes, cron state, and nested workspace repo contents.
- Restore **does not** by itself recreate the full excluded runtime/bootstrap
  layer needed for OpenClaw to attach to that data in a fresh sandbox.
- If restored files are present but `openclaw status --deep` or
  `openclaw agent` still fail, treat that as runtime/bootstrap drift rather than
  archive loss.

---

## Manual Operations

```bash
carbonite-backup                         # incremental backup (auto-freezes)
carbonite-backup "pre-upgrade snapshot"  # custom message
carbonite-bundle status                  # show nested repos & bundles
carbonite-bundle freeze                  # manually freeze nested repos
carbonite-bundle thaw                    # restore .git dirs from bundles
```

---

## Cron Job Reference

| Field | Value |
|-------|-------|
| Name | Carbonite backup |
| Schedule | `0 */4 * * *` (every 4 hours) |
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
8. **Credentials are plaintext** — PAT stored in `~/.git-credentials`. Acceptable for
   alpha; use low-scope dedicated token and rotate regularly.
9. **Sandbox Git TLS remains unresolved** — Current scratch validation still needs a
   repo-scoped TLS bypass for sandbox `git` when talking to GitHub.

---

## File Inventory

| File | Location | Purpose |
|------|----------|---------|
| `carbonite/carbonite-init.sh` | `~/carbonite/` | One-time setup or `--continue` after restore |
| `carbonite/carbonite-cron-setup.sh` | `~/carbonite/` | Register scheduled backup during fresh setup or after restore |
| `carbonite/bin/carbonite-backup` | `~/carbonite/bin/` | Incremental backup with auto-freeze + lock |
| `carbonite/bin/carbonite-bundle` | `~/carbonite/bin/` | Freeze/thaw nested git repos |
| `carbonite/bin/env-setup` | `~/carbonite/bin/` | Recreate excluded `~/.env` template after rebuild |
| `carbonite-restore.sh` | Host only | Restore sandbox from GitHub backup |
| `.gitignore` | `~/` (written by init) | Exclusion rules |
| `.carbonite.bundle` | Next to each nested `.git` | Frozen git repo snapshot |
| `.carbonite.lock` | `~/` (runtime) | Prevents concurrent backups |
