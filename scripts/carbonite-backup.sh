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
