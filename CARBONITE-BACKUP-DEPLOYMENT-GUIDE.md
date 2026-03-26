# Carbonite Backup — Deployment Guide
## For NemoClaw/OpenShell/OpenClaw sandbox on Hetzner CX33

---

## Overview

Carbonite is a git-based backup system for the ephemeral OpenClaw sandbox. It
preserves OpenClaw state (agent config, sessions, identity, workspace, cron jobs,
custom scripts) across the frequent tear-down/rebuild cycles driven by alpha-era
NemoClaw and OpenShell commit velocity.

Carbonite does **NOT** protect against pod restarts transparently — after a
rebuild, you restore from the last backup into a clean sandbox.

### Design Assumptions

- Sandbox is disposable — restore targets a **clean post-creation sandbox**
- Rebuilds are frequent (near-daily during alpha)
- Host-side patches (fetch-guard, openclaw.json, network policy) are outside
  Carbonite's scope — those require Priority 2 (custom image) to persist
- PAT-based auth is expedient for alpha; rotate regularly

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

- `.openclaw/agents/` — agent config, models.json, sessions (continuity)
- `.openclaw/workspace/` — SOUL.md, AGENTS.md, IDENTITY.md, USER.md, etc.
- `.openclaw-data/workspace/` — same (may be symlinked to above)
- `.openclaw/cron/` — scheduled job definitions
- `~/bin/` — custom scripts (websearch, carbonite-backup, carbonite-bundle)
- `.bashrc`, `.profile` — shell customizations
- `.carbonite.bundle` files — frozen snapshots of nested git repo state

## What's Excluded

- All nested `.git` directories (archived as `.carbonite.bundle` instead)
- Credentials (`.git-credentials`, `identity/`, `auth-profiles.json`)
- Shell history (`.bash_history`)
- npm packages (`.npm-global/`, `node_modules/`)
- Caches (`.openclaw/cache/`, `completions/`, `snapshots/`)
- Skills from clawhub (`skills/` — reproducible via `clawhub install`)
- Chromium / browser artifacts
- Carbonite lock file (`.carbonite.lock`)

---

## Fresh Sandbox Setup (first time ever)

### Step 1: Upload scripts to sandbox

```bash
openshell sandbox upload my-assistant ./carbonite-init.sh ~/carbonite-init.sh
openshell sandbox upload my-assistant ./carbonite-cron-setup.sh ~/carbonite-cron-setup.sh
```

### Step 2: Run initialization

Inside the sandbox (`nemoclaw my-assistant connect`):

```bash
GH_PAT=ghp_your_token_here bash ~/carbonite-init.sh
```

### Step 3: Set up scheduled backups

```bash
bash ~/carbonite-cron-setup.sh
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

### On the host:

```bash
GH_PAT=ghp_xxx bash carbonite-restore.sh my-assistant
```

### Inside the new sandbox:

```bash
# Re-init with history preservation + thaw + validation
GH_PAT=ghp_xxx bash ~/carbonite-init.sh --continue

# Re-register cron job (idempotent — safe to re-run)
bash ~/carbonite-cron-setup.sh

# Verify
carbonite-bundle status
carbonite-backup 'post-restore verification'
```

### Host-side patches still needed (until Priority 2 custom image):

1. **Fetch-guard patch** — `docker exec` sed commands (session notes Step 3)
2. **openclaw.json web config** — `docker cp` (session notes Step 4)
3. **Network policy** — `openshell policy set` (session notes Step 5)
4. **Gateway restart inside sandbox** — kill old process, `openclaw gateway &`

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
3. **Host-side patches not covered** — Container overlay changes are out of scope.
4. **Git push requires network policy** — `github` policy entry must be present.
5. **Session data may grow** — Monitor with `du -sh ~/.openclaw/agents/main/sessions/`.
6. **Bundle thaw is non-standard** — Post-thaw validation checks for sanity but cannot
   guarantee OpenClaw will behave identically to pre-backup state. Monitor for issues
   across rebuild cycles.
7. **Credentials are plaintext** — PAT stored in `~/.git-credentials`. Acceptable for
   alpha; use low-scope dedicated token and rotate regularly.

---

## File Inventory

| File | Location | Purpose |
|------|----------|---------|
| `carbonite-init.sh` | `~/` (uploaded) | One-time setup or `--continue` after restore |
| `carbonite-backup` | `~/bin/` (installed by init) | Incremental backup with auto-freeze + lock |
| `carbonite-bundle` | `~/bin/` (installed by init) | Freeze/thaw nested git repos |
| `carbonite-cron-setup.sh` | `~/` (uploaded) | Register scheduled backup (idempotent) |
| `carbonite-restore.sh` | Host only | Restore sandbox from GitHub backup |
| `.gitignore` | `~/` (written by init) | Exclusion rules |
| `.carbonite.bundle` | Next to each nested `.git` | Frozen git repo snapshot |
| `.carbonite.lock` | `~/` (runtime) | Prevents concurrent backups |
