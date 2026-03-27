#!/bin/bash
# =============================================================================
# carbonite-init.sh — Initialize Carbonite backup in a fresh OpenClaw sandbox
# =============================================================================
# Run this INSIDE the sandbox after a rebuild.
# Prerequisites:
#   - GitHub PAT with repo scope (will be prompted or set GH_PAT env var)
#   - git installed in sandbox (should be available by default)
#
# This script:
#   1. Configures git identity & credentials
#   2. Creates .gitignore tuned for OpenClaw sandbox
#   3. Installs carbonite-bundle, carbonite-backup helper scripts to ~/carbonite/bin/
#   4. Freezes nested git repos into .bundle files (git bundle)
#   5. Initializes Carbonite repo at /sandbox (HOME)
#   6. Pushes to the configured Carbonite archive repo
#
# Usage:
#   GH_PAT=ghp_xxx bash carbonite-init.sh              # fresh start (force-push)
#   GH_PAT=ghp_xxx bash carbonite-init.sh --continue    # after restore (preserves history)
#   CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
#     GH_PAT=ghp_xxx bash carbonite-init.sh             # disposable validation target
#   bash carbonite-init.sh                               # will prompt for PAT
# =============================================================================

set -euo pipefail

DEFAULT_REPO_URL="https://github.com/snarkipus/carbonite.git"
DEFAULT_REPO_NAME="snarkipus/carbonite"
REPO_URL="${CARBONITE_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_NAME="${CARBONITE_REPO_NAME:-${REPO_URL#https://github.com/}}"
REPO_NAME="${REPO_NAME%.git}"
if [ -z "$REPO_NAME" ]; then
  REPO_NAME="$DEFAULT_REPO_NAME"
fi
CONTINUE_MODE=false
CARBONITE_HOME="$HOME/carbonite"
CARBONITE_BIN_DIR="$CARBONITE_HOME/bin"

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --continue) CONTINUE_MODE=true ;;
  esac
done

# ── Git identity ────────────────────────────────────────────────────────────
echo "==> Configuring git identity..."
git config --global user.name "snarkipus"
git config --global user.email "snarkipus@users.noreply.github.com"
git config --global init.defaultBranch main

# Some sandbox images ship CA bundles that curl can use, but git does not pick
# up automatically. Point git at the standard bundle/dir explicitly when present.
if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
  git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
fi
if [ -d /etc/ssl/certs ]; then
  git config --global http.sslCAPath /etc/ssl/certs
fi

# ── GitHub PAT ──────────────────────────────────────────────────────────────
if [ -z "${GH_PAT:-}" ]; then
  read -rsp "GitHub PAT (repo scope): " GH_PAT
  echo
fi

if [ -z "$GH_PAT" ]; then
  echo "ERROR: No GitHub PAT provided. Aborting."
  exit 1
fi

# Store credentials for HTTPS push (sandbox can't do SSH easily)
git config --global credential.helper store
echo "https://snarkipus:${GH_PAT}@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials

# ── .gitignore ──────────────────────────────────────────────────────────────
echo "==> Writing .gitignore..."
cat > ~/.gitignore << 'GITIGNORE'
# =============================================================================
# Carbonite .gitignore — OpenClaw sandbox backup
# Last updated: 2026-03-22
# =============================================================================

# ── Secrets & credentials (NEVER track) ─────────────────────────────────────
.git-credentials
.openclaw/identity/
.openclaw-data/identity/
.openclaw-data/devices/
.openclaw/agents/*/agent/auth-profiles.json
.openclaw-data/agents/*/agent/auth-profiles.json

# ── Bootstrap/runtime config (recreated, not preserved) ────────────────────
.nemoclaw/
.openclaw/openclaw.json
.openclaw/openclaw.json.bak
.openclaw/openclaw.json.bak.*
.openclaw/.config-hash

# ── OpenClaw facade tree (capture canonical .openclaw-data instead) ─────────
.openclaw/*
!.openclaw/memory/
!.openclaw/memory/*.sqlite

# ── Shell history (noise, potential secret leakage) ─────────────────────────
.bash_history
.lesshst
.python_history

# ── npm / node (large, reproducible) ────────────────────────────────────────
.npm-global/
.npm/
.npmrc
**/node_modules/

# ── OpenClaw caches & ephemeral data ────────────────────────────────────────
.openclaw/cache/
.openclaw/snapshots/
.openclaw/completions/
.openclaw/logs/
.openclaw-data/update-check.json
.openclaw/update-check.json
.openclaw/memory/*.wal
.openclaw/memory/*.sqlite-wal
.openclaw/memory/*.sqlite-shm

# ── Misc app config (reproducible, not worth tracking) ──────────────────────
.config/
.clawhub/

# ── Temp files & logs ───────────────────────────────────────────────────────
/tmp/
*.log
*.tmp
*.bak
*.swp
*~

# ── Browser / Chromium (if agent-browser ever gets installed) ───────────────
**/chromium/

# ── Skills installed via clawhub (reproducible via clawhub install) ──────────
skills/

# ── OS junk ─────────────────────────────────────────────────────────────────
.DS_Store
Thumbs.db

# ── Carbonite internals ─────────────────────────────────────────────────────
.carbonite.lock

# ── Nested git repos ────────────────────────────────────────────────────────
# Nested .git dirs are archived as .carbonite.bundle files by carbonite-bundle.
# During freeze, .git is renamed to .git.frozen to prevent submodule detection.
# Both must be excluded from Carbonite tracking.
**/.git
**/.git.frozen
GITIGNORE

stage_preserved_paths() {
  local path
  for path in \
    ".openclaw-data/agents" \
    ".openclaw-data/workspace" \
    ".openclaw-data/cron" \
    ".openclaw/memory" \
    "carbonite" \
    ".bashrc" \
    ".profile" \
    ".gitconfig" \
    ".gitignore"
  do
    [ -e "$path" ] || continue
    git add -A -- "$path"
  done
}

drop_excluded_paths() {
  git rm -r --cached --ignore-unmatch -- \
    ".nemoclaw" \
    ".openclaw/openclaw.json" \
    ".openclaw/openclaw.json.bak" \
    ".openclaw/openclaw.json.bak.*" \
    ".openclaw/.config-hash" \
    ".openclaw/identity" \
    ".openclaw-data/identity" \
    ".openclaw-data/devices" \
    ".openclaw/logs" \
    ".openclaw-data/update-check.json" \
    ".openclaw/update-check.json" \
    ".openclaw/agents/*/agent/auth-profiles.json" \
    ".openclaw-data/agents/*/agent/auth-profiles.json" \
    ".git-credentials"
}

# ── Install helper scripts ─────────────────────────────────────────────────
echo "==> Installing helper scripts to ~/carbonite/bin/..."
mkdir -p "$CARBONITE_BIN_DIR"

# ── carbonite-bundle: freeze/thaw nested git repos ─────────────────────────
cat > "$CARBONITE_BIN_DIR/carbonite-bundle" << 'BUNDLE_SCRIPT'
#!/bin/bash
# =============================================================================
# carbonite-bundle — Freeze/thaw nested git repos for Carbonite backup
# =============================================================================
# Nested git repos (like OpenClaw's workspace) prevent `git add -A` from
# working because git interprets them as submodules. This script converts
# them to/from portable .bundle files using `git bundle`.
#
# Usage:
#   carbonite-bundle freeze    # .git dirs → .carbonite.bundle files
#   carbonite-bundle thaw      # .carbonite.bundle files → .git dirs
#   carbonite-bundle status    # show nested repos and bundle state
# =============================================================================

set -euo pipefail

cd ~

ACTION="${1:-status}"

# Find nested .git directories (exclude Carbonite's own top-level .git)
find_nested_gits() {
  find . -mindepth 2 -name ".git" -type d \
    ! -path "./.git/*" \
    2>/dev/null
}

# Find .carbonite.bundle files (and tar fallbacks)
find_bundles() {
  find . \( -name ".carbonite.bundle" -o -name ".carbonite.bundle.tar" \) \
    -type f \
    ! -path "./.git/*" \
    2>/dev/null
}

case "$ACTION" in
  freeze)
    echo "[carbonite-bundle] Freezing nested git repos..."
    FOUND=0
    while IFS= read -r gitdir; do
      PARENT=$(dirname "$gitdir")
      BUNDLE="${PARENT}/.carbonite.bundle"

      echo "  → ${PARENT}/"

      # Create bundle from the nested repo (captures full history)
      if git -C "$PARENT" bundle create "${BUNDLE}.tmp" --all 2>/dev/null; then
        mv "${BUNDLE}.tmp" "$BUNDLE"
        SIZE=$(du -sh "$BUNDLE" | cut -f1)
        echo "    Bundled (${SIZE})"
        FOUND=$((FOUND + 1))
      else
        # Bundle fails on repos with no commits — fall back to tar
        echo "    WARN: git bundle failed (no commits?), using tar fallback"
        tar -cf "${PARENT}/.carbonite.bundle.tar" -C "$PARENT" .git 2>/dev/null && {
          FOUND=$((FOUND + 1))
          echo "    Tar fallback created"
        } || {
          echo "    ERROR: Could not archive ${PARENT}/.git"
          continue
        }
      fi

      # Move .git out of the way so git add -A won't hit submodule detection.
      # .gitignore (**/.git) handles subsequent runs, but the initial git add
      # on a fresh repo triggers submodule detection BEFORE reading .gitignore.
      mv "${PARENT}/.git" "${PARENT}/.git.frozen"
      echo "    Moved .git → .git.frozen"
    done < <(find_nested_gits)

    if [ "$FOUND" -eq 0 ]; then
      echo "  No nested git repos found."
    else
      echo "  Froze ${FOUND} nested repo(s)."
    fi
    ;;

  thaw)
    echo "[carbonite-bundle] Thawing bundles back to git repos..."
    FOUND=0
    while IFS= read -r bundle; do
      PARENT=$(dirname "$bundle")
      BASENAME=$(basename "$bundle")

      echo "  → ${PARENT}/"

      # Skip if .git already exists and is populated
      if [ -d "${PARENT}/.git" ] && [ -f "${PARENT}/.git/HEAD" ]; then
        echo "    .git already exists, skipping"
        continue
      fi

      if [[ "$BASENAME" == *.tar ]]; then
        # Tar fallback — extract directly
        tar -xf "$bundle" -C "$PARENT" 2>/dev/null && {
          echo "    Restored from tar fallback"
          rm -f "$bundle"
          rm -rf "${PARENT}/.git.frozen" 2>/dev/null
        } || {
          echo "    ERROR: Could not extract tar bundle"
        }
      else
        # ── Standard thaw: init → fetch → checkout → reset ──────────────
        # This follows the idiomatic git pattern for materializing a repo
        # from a bundle into an existing directory with working tree files.

        # Clean any partial .git state
        rm -rf "${PARENT}/.git"

        # Initialize a fresh repo in the workspace directory
        git -C "$PARENT" init -q

        # Add the bundle as a temporary remote and fetch refs into tracking namespace
        git -C "$PARENT" remote add carbonite "$bundle"
        git -C "$PARENT" fetch -q carbonite "+refs/heads/*:refs/remotes/carbonite/*" 2>/dev/null
        git -C "$PARENT" fetch -q carbonite "+refs/tags/*:refs/tags/*" 2>/dev/null || true

        # Resolve the default branch from the bundle's HEAD
        DEFAULT_REF=$(git ls-remote --symref "$bundle" HEAD 2>/dev/null \
                      | awk '/^ref:/ {print $2}' \
                      | sed 's#refs/heads/##')
        [ -z "$DEFAULT_REF" ] && DEFAULT_REF="main"

        # Checkout the resolved branch from remote-tracking refs, or detach as fallback
        if git -C "$PARENT" show-ref --verify -q "refs/remotes/carbonite/$DEFAULT_REF" 2>/dev/null; then
          git -C "$PARENT" checkout -q -B "$DEFAULT_REF" "refs/remotes/carbonite/$DEFAULT_REF" 2>/dev/null
        else
          # No matching branch — detach to whatever FETCH_HEAD points at
          git -C "$PARENT" checkout -q --detach FETCH_HEAD 2>/dev/null || true
        fi

        # Hard reset to align index + working tree with HEAD
        git -C "$PARENT" reset --hard -q 2>/dev/null || true

        # Remove the temporary remote
        git -C "$PARENT" remote remove carbonite 2>/dev/null || true

        # Clean up frozen .git from freeze step (if present)
        rm -rf "${PARENT}/.git.frozen" 2>/dev/null

        # ── Post-thaw validation ────────────────────────────────────────
        THAW_OK=true
        if ! git -C "$PARENT" rev-parse --is-inside-work-tree &>/dev/null; then
          echo "    WARN: not recognized as a work tree after thaw"
          THAW_OK=false
        fi

        HEAD_REF=$(git -C "$PARENT" symbolic-ref -q HEAD 2>/dev/null \
                   || git -C "$PARENT" rev-parse --short HEAD 2>/dev/null \
                   || echo "NONE")
        PORCELAIN=$(git -C "$PARENT" status --porcelain 2>/dev/null | wc -l)
        LAST_MSG=$(git -C "$PARENT" log -1 --format="%s" 2>/dev/null || echo "n/a")

        if [ "$THAW_OK" = true ]; then
          echo "    Restored (HEAD: ${HEAD_REF}, dirty: ${PORCELAIN}, last: ${LAST_MSG})"
        else
          echo "    WARN: Thaw completed but validation failed — repo may need manual repair"
        fi

        rm -f "$bundle"
      fi
      FOUND=$((FOUND + 1))
    done < <(find_bundles)

    if [ "$FOUND" -eq 0 ]; then
      echo "  No bundles found to thaw."
    fi
    ;;

  status)
    echo "[carbonite-bundle] Nested git repos:"
    GITS=0
    while IFS= read -r gitdir; do
      PARENT=$(dirname "$gitdir")
      BRANCH=$(git -C "$PARENT" branch --show-current 2>/dev/null || echo "detached/empty")
      COMMITS=$(git -C "$PARENT" rev-list --count HEAD 2>/dev/null || echo "0")
      echo "  ${PARENT}/ (branch: ${BRANCH}, commits: ${COMMITS})"
      GITS=$((GITS + 1))
    done < <(find_nested_gits)
    [ "$GITS" -eq 0 ] && echo "  (none)" || true

    echo ""
    echo "[carbonite-bundle] Existing bundles:"
    BUNDLES=0
    while IFS= read -r bundle; do
      echo "  ${bundle} ($(du -sh "$bundle" | cut -f1))"
      BUNDLES=$((BUNDLES + 1))
    done < <(find_bundles)
    [ "$BUNDLES" -eq 0 ] && echo "  (none)" || true
    ;;

  *)
    echo "Usage: carbonite-bundle {freeze|thaw|status}"
    exit 1
    ;;
esac
BUNDLE_SCRIPT
chmod +x "$CARBONITE_BIN_DIR/carbonite-bundle"

# ── carbonite-backup: incremental backup with auto-freeze ───────────────────
cat > "$CARBONITE_BIN_DIR/carbonite-backup" << 'BACKUP_SCRIPT'
#!/bin/bash
# =============================================================================
# carbonite-backup — Incremental git backup of sandbox state
# =============================================================================
# Idempotent: no-ops if working tree is clean.
# Automatically freezes nested git repos before staging.
# Uses flock to prevent concurrent runs (cron + manual overlap).
# Commit always succeeds locally; push failure is non-fatal.
#
# Usage:
#   carbonite-backup                    # auto-generated commit message
#   carbonite-backup "manual snapshot"  # custom commit message
# =============================================================================

set -euo pipefail

LOCKFILE="${HOME}/.carbonite.lock"

# ── Acquire exclusive lock (fail immediately if another run is active) ──────
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[carbonite] Another backup is already running. Skipping."
  exit 0
fi

cd ~

MSG="${1:-carbonite: scheduled backup $(date -u +%Y-%m-%dT%H:%M:%SZ)}"

stage_preserved_paths() {
  local path
  for path in \
    ".openclaw-data/agents" \
    ".openclaw-data/workspace" \
    ".openclaw-data/cron" \
    ".openclaw/memory" \
    "carbonite" \
    ".bashrc" \
    ".profile" \
    ".gitconfig" \
    ".gitignore"
  do
    [ -e "$path" ] || continue
    git add -A -- "$path"
  done
}

drop_excluded_paths() {
  git rm -r --cached --ignore-unmatch -- \
    ".nemoclaw" \
    ".openclaw/openclaw.json" \
    ".openclaw/openclaw.json.bak" \
    ".openclaw/openclaw.json.bak.*" \
    ".openclaw/.config-hash" \
    ".openclaw/identity" \
    ".openclaw-data/identity" \
    ".openclaw-data/devices" \
    ".openclaw/logs" \
    ".openclaw-data/update-check.json" \
    ".openclaw/update-check.json" \
    ".openclaw/agents/*/agent/auth-profiles.json" \
    ".openclaw-data/agents/*/agent/auth-profiles.json" \
    ".git-credentials"
}

# Freeze nested git repos into .bundle files
carbonite-bundle freeze

# Stage only the validated continuity paths, then drop tracked exclusions
stage_preserved_paths
drop_excluded_paths

# Check if there's anything to commit
if git diff --cached --quiet; then
  # Nothing new to commit — but check for unpushed commits from failed pushes
  UNPUSHED=$(git log --oneline origin/main..HEAD 2>/dev/null | wc -l)
  if [ "$UNPUSHED" -gt 0 ]; then
    echo "[carbonite] No new changes, but ${UNPUSHED} unpushed commit(s) found. Retrying push..."
    if git push origin main 2>&1; then
      echo "[carbonite] Push retry succeeded."
    else
      echo "[carbonite] WARN: Push retry failed. Will try again next run."
    fi
  else
    echo "[carbonite] Working tree clean, nothing to commit."
  fi
  exit 0
fi

# Show what changed (for logging)
echo "[carbonite] Changes detected:"
git diff --cached --stat

# Commit locally (always succeeds if staging worked)
git commit -m "$MSG"
echo "[carbonite] Committed locally."

# Push to remote (non-fatal — local commit is preserved on failure)
if git push origin main 2>&1; then
  echo "[carbonite] Backup pushed successfully."
else
  echo "[carbonite] WARN: Push failed (network/auth issue?). Local commit preserved."
  echo "[carbonite] Will retry on next backup run. Manual: git push origin main"
fi
BACKUP_SCRIPT
chmod +x "$CARBONITE_BIN_DIR/carbonite-backup"

# Make sure ~/carbonite/bin is in PATH
PATH_EXPORT="export PATH=\"\$HOME/carbonite/bin:\$PATH\""
if ! grep -Fq "$PATH_EXPORT" ~/.bashrc 2>/dev/null; then
  printf '%s\n' "$PATH_EXPORT" >> ~/.bashrc
fi
export PATH="$HOME/carbonite/bin:$PATH"

# ── Freeze nested repos ────────────────────────────────────────────────────
echo ""
echo "==> Scanning for nested git repos..."
carbonite-bundle status

echo ""
echo "==> Freezing nested git repos into bundles..."
carbonite-bundle freeze

# ── Initialize Carbonite repo ──────────────────────────────────────────────
cd ~
echo ""
echo "==> Initializing Carbonite repo in $(pwd)..."

if [ "$CONTINUE_MODE" = true ]; then
  echo "    --continue mode: cloning existing history..."
  if [ -d .git ]; then
    rm -rf .git
  fi
  if git clone --bare "${REPO_URL}" /tmp/carbonite-bare.$$ 2>/dev/null; then
    mv /tmp/carbonite-bare.$$ .git
    git config --unset core.bare
    git reset HEAD -- . 2>/dev/null || true
    echo "    Existing history preserved ($(git rev-list --count HEAD 2>/dev/null || echo 0) commits)"
  else
    echo "    WARN: Could not clone existing repo, starting fresh..."
    git init
  fi

  # ── Verify restore integrity ──────────────────────────────────────────────
  echo ""
  echo "==> Verifying restore integrity..."
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    MISSING=$(git ls-files --deleted 2>/dev/null | wc -l)
    MODIFIED=$(git diff --name-only HEAD 2>/dev/null | wc -l)
    TRACKED=$(git ls-files 2>/dev/null | wc -l)

    echo "    Tracked files in last backup: ${TRACKED}"
    echo "    Missing after restore:        ${MISSING}"
    echo "    Modified after restore:       ${MODIFIED}"

    if [ "$MISSING" -gt 0 ]; then
      echo ""
      echo "    WARN: Missing files (may be expected if sandbox image differs):"
      git ls-files --deleted 2>/dev/null | head -20 | sed 's/^/      /'
      REMAINING=$((MISSING - 20))
      if [ "$REMAINING" -gt 0 ]; then
        echo "      ... and ${REMAINING} more"
      fi
    fi

    if [ "$MISSING" -eq 0 ] && [ "$MODIFIED" -eq 0 ]; then
      echo "    ✓ Restore matches last backup exactly."
    fi
  else
    echo "    No existing Carbonite history found."
    echo "    Continuing with restored filesystem snapshot and fresh top-level repo."
  fi

  # ── Thaw bundles back to .git dirs ────────────────────────────────────────
  echo ""
  echo "==> Thawing nested git repos from bundles..."
  carbonite-bundle thaw

  echo ""
  echo "==> Post-thaw verification..."
  carbonite-bundle status

  # Remove the host-uploaded restore transport archive before staging.
  # It is only needed to materialize the restored filesystem snapshot.
  rm -f ~/carbonite-restore.tar

  # ── Stage, commit if needed, push ─────────────────────────────────────────
  # Re-freeze after thaw so the .gitignore-excluded .git dirs don't cause
  # issues, and any new .bundle files reflect current state
  carbonite-bundle freeze

  stage_preserved_paths
  drop_excluded_paths
  if ! git diff --cached --quiet; then
    git commit -m "carbonite: restored backup ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  else
    echo "    No changes from remote — working tree matches last backup."
  fi
  git remote add origin "${REPO_URL}" 2>/dev/null || git remote set-url origin "${REPO_URL}"
  git push -u origin main
else
  if [ -d .git ]; then
    echo "    Git repo already exists, removing to start fresh..."
    rm -rf .git
  fi
  git init
  stage_preserved_paths
  drop_excluded_paths
  git commit -m "carbonite: initial backup ($(date -u +%Y-%m-%dT%H:%M:%SZ))"

  echo "==> Force-pushing to ${REPO_NAME} (this will overwrite remote)..."
  git remote add origin "${REPO_URL}" 2>/dev/null || git remote set-url origin "${REPO_URL}"
  git push --force -u origin main
fi

echo ""
echo "==> Carbonite initialized successfully!"
echo "    Repo: ${REPO_NAME}"
echo "    Branch: main"
echo "    Tracked files: $(git ls-files | wc -l)"
echo ""
echo "==> Available commands:"
echo "    carbonite-backup                    # incremental backup (auto-freezes)"
echo "    carbonite-backup 'my message'       # backup with custom message"
echo "    carbonite-bundle status             # show nested repos & bundles"
echo "    carbonite-bundle freeze             # manually freeze nested repos"
echo "    carbonite-bundle thaw               # restore .git dirs from bundles"
echo ""
echo "==> To set up scheduled backups via OpenClaw cron:"
cat <<'CRON_EXAMPLE'
    openclaw cron add \
      --name "Carbonite backup" \
      --cron "0 */4 * * *" \
      --tz "America/New_York" \
      --session isolated \
      --message "Run this shell command and report the output: carbonite-backup" \
      --light-context
CRON_EXAMPLE
echo ""
