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

CARBONITE_REPO_ROOT="$HOME/.openclaw-data"
CARBONITE_BIN_DIR="$CARBONITE_REPO_ROOT/carbonite/bin"
CARBONITE_ENV_HELPER="$CARBONITE_REPO_ROOT/carbonite/env.sh"
LOCKFILE="${CARBONITE_REPO_ROOT}/.carbonite.lock"

# ── Acquire exclusive lock (fail immediately if another run is active) ──────
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[carbonite] Another backup is already running. Skipping."
  exit 0
fi

cd "$CARBONITE_REPO_ROOT"

MSG="${1:-carbonite: scheduled backup $(date -u +%Y-%m-%dT%H:%M:%SZ)}"

source_carbonite_env() {
  if [ -f "$CARBONITE_ENV_HELPER" ]; then
    # shellcheck disable=SC1090
    . "$CARBONITE_ENV_HELPER"
  fi
}

has_materialized_github_token() {
  [ -n "${GITHUB_TOKEN:-}" ] && [[ "$GITHUB_TOKEN" != openshell:resolve:env:* ]]
}

git_auth_args() {
  if has_materialized_github_token; then
    local auth
    auth=$(printf '%s' "x-access-token:${GITHUB_TOKEN}" | base64 | tr -d '\n')
    printf '%s\n' \
      "-c" \
      "credential.helper=" \
      "-c" \
      "http.https://github.com/.extraHeader=Authorization: Basic ${auth}"
  fi
}

run_git() {
  local -a args=()
  while IFS= read -r line; do
    args+=("$line")
  done < <(git_auth_args)
  git "${args[@]}" "$@"
}

source_carbonite_env

stage_preserved_paths() {
  local path
  for path in \
    "agents" \
    "canvas" \
    "workspace" \
    "cron" \
    "flows" \
    "hooks" \
    "media" \
    "memory" \
    "qmd" \
    "sandbox" \
    "skills" \
    "tasks" \
    "telegram" \
    "wiki" \
    "carbonite" \
    ".gitignore"
  do
    [ -e "$path" ] || continue
    git add -A -- "$path"
  done
}

drop_excluded_paths() {
  git rm -r --cached --ignore-unmatch -- \
    "credentials" \
    "identity" \
    "devices" \
    "exec-approvals.json" \
    "update-check.json" \
    "extensions" \
    "logs" \
    "plugin-runtime-deps" \
    "openclaw.json.bak-*" \
    "agents/*/qmd/xdg-cache" \
    "agents/*/qmd/xdg-config" \
    "agents/*/agent/auth-profiles.json" \
    "carbonite/.git-credentials" \
    "carbonite/env.sh"
}

# Freeze nested git repos into .bundle files
"$CARBONITE_BIN_DIR/carbonite-bundle" freeze

# Stage only the validated continuity paths, then drop tracked exclusions
stage_preserved_paths
drop_excluded_paths

# Check if there's anything to commit
if git diff --cached --quiet; then
  # Nothing new to commit — but check for unpushed commits from failed pushes
  UNPUSHED=$(git log --oneline origin/main..HEAD 2>/dev/null | wc -l)
  if [ "$UNPUSHED" -gt 0 ]; then
    echo "[carbonite] No new changes, but ${UNPUSHED} unpushed commit(s) found. Retrying push..."
    if run_git push origin main 2>&1; then
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
if run_git push origin main 2>&1; then
  echo "[carbonite] Backup pushed successfully."
else
  echo "[carbonite] WARN: Push failed (network/auth issue?). Local commit preserved."
  echo "[carbonite] Will retry on next backup run. Manual: git push origin main"
fi
