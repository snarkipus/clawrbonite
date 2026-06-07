#!/bin/bash
# =============================================================================
# carbonite-init.sh — Initialize Carbonite backup in a fresh OpenClaw sandbox
# =============================================================================
# Run this INSIDE the sandbox after a rebuild.
# Prerequisites:
#   - GitHub CLI (`gh`) installed in the sandbox image
#   - GitHub CLI auth available via the runtime `GITHUB_TOKEN` provider
#   - git installed in sandbox (should be available by default)
#
# This script:
#   1. Configures git identity & credentials
#   2. Creates .gitignore tuned for OpenClaw sandbox
#   3. Installs Carbonite helpers to ~/.openclaw/carbonite/bin/
#   4. Freezes nested git repos into .bundle files (git bundle)
#   5. Initializes Carbonite repo at ~/.openclaw
#   6. Pushes to the configured Carbonite archive repo
#
# Usage:
#   bash carbonite-init.sh                               # fresh start (force-push)
#   bash carbonite-init.sh --continue                    # after restore (preserves history)
#   bash carbonite-init.sh --continue --no-push          # validation restore (no commit/push)
#   CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
#     bash carbonite-init.sh                             # disposable validation target
# =============================================================================

set -euo pipefail
set -E

on_error() {
  local status=$?
  local line=${1:-unknown}
  echo "[carbonite] ERROR: Init failed at line ${line} with status ${status}."
  exit "$status"
}

trap 'on_error $LINENO' ERR

DEFAULT_REPO_URL="https://github.com/snarkipus/carbonite.git"
DEFAULT_REPO_NAME="snarkipus/carbonite"
REPO_URL="${CARBONITE_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_NAME="${CARBONITE_REPO_NAME:-${REPO_URL#https://github.com/}}"
REPO_NAME="${REPO_NAME%.git}"
if [ -z "$REPO_NAME" ]; then
  REPO_NAME="$DEFAULT_REPO_NAME"
fi
CONTINUE_MODE=false
NO_PUSH_MODE=false
CARBONITE_REPO_ROOT="$HOME/.openclaw"
CARBONITE_HOME="$CARBONITE_REPO_ROOT/carbonite"
CARBONITE_BIN_DIR="$CARBONITE_HOME/bin"
CARBONITE_GITIGNORE="$CARBONITE_REPO_ROOT/.gitignore"
CARBONITE_ENV_HELPER="$CARBONITE_HOME/env.sh"
CARBONITE_LOCAL_HISTORY_TAR="${CARBONITE_LOCAL_HISTORY_TAR:-/tmp/carbonite-restore-upload/carbonite-history.tar}"

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --continue) CONTINUE_MODE=true ;;
    --no-push) NO_PUSH_MODE=true ;;
  esac
done

detect_runtime_root() {
  local -a candidates=()
  local candidate
  for candidate in "$HOME/.openclaw" "$HOME/.openclaw-data"; do
    [ -d "$candidate" ] || continue
    candidates+=("$candidate")
  done

  if [ "${#candidates[@]}" -eq 0 ]; then
    printf '%s\n' ""
  elif [ "${#candidates[@]}" -eq 1 ]; then
    printf '%s\n' "${candidates[0]}"
  else
    printf '%s\n' "AMBIGUOUS"
  fi
}

assert_continue_preconditions() {
  local runtime_root
  runtime_root="$(detect_runtime_root)"

  if [ "$runtime_root" = "AMBIGUOUS" ]; then
    echo "ERROR: Continue mode found multiple writable Carbonite roots."
    echo "       Refusing to guess between ~/.openclaw and ~/.openclaw-data."
    exit 1
  fi

  if [ -n "$runtime_root" ] && [ "$runtime_root" != "$CARBONITE_REPO_ROOT" ]; then
    echo "ERROR: Continue mode helper root does not match runtime root."
    echo "       Helper root:  $CARBONITE_REPO_ROOT"
    echo "       Runtime root: $runtime_root"
    echo "       Refresh the restore helpers from the current clawrbonite checkout and retry in a fresh sandbox."
    exit 1
  fi

  if [ -d "$CARBONITE_REPO_ROOT/.git" ]; then
    echo "ERROR: Found existing $CARBONITE_REPO_ROOT/.git before continue-mode restore."
    echo "       This sandbox has partial Carbonite restore state already. Discard it and retry in a fresh sandbox."
    exit 1
  fi
}

if [ "$CONTINUE_MODE" = true ]; then
  assert_continue_preconditions
fi

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

normalize_origin_remote() {
  git remote add origin "${REPO_URL}" 2>/dev/null || git remote set-url origin "${REPO_URL}"
}

source_carbonite_env

# ── Git identity ────────────────────────────────────────────────────────────
echo "==> Configuring git identity..."
git config --global user.name "snarkipus"
git config --global user.email "snarkipus@users.noreply.github.com"
git config --global init.defaultBranch main

# Some sandbox images terminate GitHub TLS through the OpenShell proxy CA.
# Prefer that CA for GitHub when present; otherwise fall back to the system
# bundle/dir so git and curl agree on trust roots.
if [ -f /etc/openshell-tls/openshell-ca.pem ]; then
  export GIT_SSL_CAINFO=/etc/openshell-tls/openshell-ca.pem
  git config --global http.https://github.com/.sslCAInfo /etc/openshell-tls/openshell-ca.pem
elif [ -f /etc/ssl/certs/ca-certificates.crt ]; then
  git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
fi
if [ -d /etc/ssl/certs ]; then
  git config --global http.sslCAPath /etc/ssl/certs
fi

# ── GitHub CLI auth ─────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh is required inside the sandbox for Carbonite init."
  exit 1
fi

# Use the runtime GitHub CLI auth and wire git through gh's credential helper.
mkdir -p "$CARBONITE_HOME"
echo "==> Checking GitHub CLI auth..."
if has_materialized_github_token; then
  echo "    Using local GITHUB_TOKEN fallback from ~/.openclaw/carbonite/env.sh for git transport."
elif ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated inside the sandbox."
  echo "       Ensure the runtime GitHub credential provider is attached before continuing,"
  echo "       or export a real GITHUB_TOKEN in ~/.openclaw/carbonite/env.sh."
  exit 1
else
  gh auth setup-git --hostname github.com
fi

# ── .gitignore ──────────────────────────────────────────────────────────────
echo "==> Writing .gitignore..."
mkdir -p "$CARBONITE_REPO_ROOT"
cat > "$CARBONITE_GITIGNORE" << 'GITIGNORE'
# =============================================================================
# Carbonite .gitignore — OpenClaw sandbox backup
# Last updated: 2026-05-05
# =============================================================================

# ── Secrets & credentials (NEVER track) ─────────────────────────────────────
agents/*/agent/auth-profiles.json

# ── Local operator helpers (recreated, not preserved) ───────────────────────
carbonite/env.sh
*.env

# ── Runtime/bootstrap artifacts (recreated, not preserved) ──────────────────
credentials/
identity/
devices/
exec-approvals.json
openclaw.json
.config-hash
openclaw.json.last-good
update-check.json
backups/
completions/
extensions/
logs/
.npm/
npm/
plugin-runtime-deps/
openclaw.json.bak-*

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
cache/
snapshots/
completions/
logs/
wiki/main/**
agents/*/qmd/xdg-cache/
agents/*/qmd/xdg-config/

# ── Operational workspace memory cursor/state (not durable continuity) ──────
workspace/memory/agentmail-last-check.json
workspace/memory/heartbeat-state.json
workspace/memory/rss-state/**
workspace/memory/rsshub-upstream-state.json
workspace/memory/wiki-watch/**

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
    "agents" \
    "canvas" \
    "workspace" \
    "hooks" \
    "media" \
    "skills" \
    "wiki" \
    ".gitignore"
  do
    [ -e "$path" ] || continue
    git add -A -- "$path"
  done
}

drop_excluded_paths() {
  local -a tracked_excluded=()
  local -a untracked_excluded=()
  mapfile -d '' -t tracked_excluded < <(git ls-files -z --cached -- \
    "credentials" \
    "identity" \
    "devices" \
    "exec-approvals.json" \
    ".config-hash" \
    "openclaw.json" \
    "openclaw.json.last-good" \
    "update-check.json" \
    "backups" \
    "completions" \
    "extensions" \
    "logs" \
    "npm" \
    "plugin-runtime-deps" \
    "carbonite" \
    "cron" \
    "flows" \
    "memory" \
    "plugins" \
    "qmd" \
    "sandbox" \
    "session-delivery-queue" \
    "tasks" \
    "telegram" \
    "wiki/main" \
    "openclaw.json.bak-*" \
    "agents/*/sessions/*.bak-*" \
    "agents/*/sessions/*.deleted.*" \
    "agents/*/sessions/*.reset.*" \
    "agents/*/sessions/*.lock" \
    "agents/*/qmd/xdg-cache" \
    "agents/*/qmd/xdg-config" \
    "agents/*/agent/auth-profiles.json" \
    "carbonite/.git-credentials" \
    "carbonite/env.sh" \
    "workspace/.carbonite.bundle.tar" \
    "workspace/.openclaw/workspace-state.json" \
    "workspace/memory/agentmail-last-check.json" \
    "workspace/memory/heartbeat-state.json" \
    "workspace/memory/rss-state" \
    "workspace/memory/rsshub-upstream-state.json" \
    "workspace/memory/wiki-watch") || true

  mapfile -d '' -t untracked_excluded < <(git ls-files -z --others --exclude-standard -- \
    "credentials" \
    "identity" \
    "devices" \
    "exec-approvals.json" \
    ".config-hash" \
    "openclaw.json" \
    "openclaw.json.last-good" \
    "update-check.json" \
    "backups" \
    "completions" \
    "extensions" \
    "logs" \
    "npm" \
    "plugin-runtime-deps" \
    "carbonite" \
    "cron" \
    "flows" \
    "memory" \
    "plugins" \
    "qmd" \
    "sandbox" \
    "session-delivery-queue" \
    "tasks" \
    "telegram" \
    "wiki/main" \
    "openclaw.json.bak-*" \
    "agents/*/sessions/*.bak-*" \
    "agents/*/sessions/*.deleted.*" \
    "agents/*/sessions/*.reset.*" \
    "agents/*/sessions/*.lock" \
    "agents/*/qmd/xdg-cache" \
    "agents/*/qmd/xdg-config" \
    "agents/*/agent/auth-profiles.json" \
    "carbonite/env.sh" \
    "workspace/.carbonite.bundle.tar" \
    "workspace/.openclaw/workspace-state.json" \
    "workspace/memory/agentmail-last-check.json" \
    "workspace/memory/heartbeat-state.json" \
    "workspace/memory/rss-state" \
    "workspace/memory/rsshub-upstream-state.json" \
    "workspace/memory/wiki-watch") || true

  if [ "${#tracked_excluded[@]}" -gt 0 ]; then
    git rm -q -r --cached --ignore-unmatch -- "${tracked_excluded[@]}"
    git update-index --force-remove -- "${tracked_excluded[@]}" 2>/dev/null || true
  fi

  if [ "${#untracked_excluded[@]}" -gt 0 ]; then
    git rm -q -r --cached --ignore-unmatch -- "${untracked_excluded[@]}" || true
  fi
}

# ── Install helper scripts ─────────────────────────────────────────────────
echo "==> Installing helper scripts to ~/.openclaw/carbonite/bin/..."
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

CARBONITE_REPO_ROOT="$HOME/.openclaw"

cd "$CARBONITE_REPO_ROOT"

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
#   carbonite-backup --help             # show usage
# =============================================================================

set -euo pipefail
set -E

on_error() {
  local status=$?
  local line=${1:-unknown}
  echo "[carbonite] ERROR: Backup failed at line ${line} with status ${status}."
  exit "$status"
}

trap 'on_error $LINENO' ERR

CARBONITE_REPO_ROOT="$HOME/.openclaw"
CARBONITE_BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARBONITE_ENV_HELPER="$CARBONITE_REPO_ROOT/carbonite/env.sh"
LOCKFILE="${CARBONITE_REPO_ROOT}/.carbonite.lock"
MSG=""

print_usage() {
  cat <<'USAGE'
Usage:
  carbonite-backup
  carbonite-backup "manual snapshot label"
  carbonite-backup --help

Creates an incremental Carbonite backup. With no label, the commit message is
generated automatically. Labels must be a single non-empty argument and cannot
start with '-'.
USAGE
}

parse_args() {
  if [ "$#" -eq 0 ]; then
    MSG="carbonite: scheduled backup $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    return 0
  fi

  if [ "$#" -ne 1 ]; then
    echo "[carbonite] ERROR: Expected at most one backup label." >&2
    print_usage >&2
    exit 2
  fi

  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    "")
      echo "[carbonite] ERROR: Backup label cannot be empty." >&2
      print_usage >&2
      exit 2
      ;;
    -*)
      echo "[carbonite] ERROR: Unknown option or invalid backup label: $1" >&2
      print_usage >&2
      exit 2
      ;;
    *)
      MSG="$1"
      ;;
  esac
}

parse_args "$@"

# ── Acquire exclusive lock (fail immediately if another run is active) ──────
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[carbonite] Another backup is already running. Skipping."
  exit 0
fi

cd "$CARBONITE_REPO_ROOT"

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
    "hooks" \
    "media" \
    "skills" \
    "wiki" \
    ".gitignore"
  do
    [ -e "$path" ] || continue
    git add -A -- "$path"
  done
}

drop_excluded_paths() {
  local -a tracked_excluded=()
  local -a untracked_excluded=()
  mapfile -d '' -t tracked_excluded < <(git ls-files -z --cached -- \
    "credentials" \
    "identity" \
    "devices" \
    "exec-approvals.json" \
    ".config-hash" \
    "openclaw.json" \
    "openclaw.json.last-good" \
    "update-check.json" \
    "backups" \
    "completions" \
    "extensions" \
    "logs" \
    "npm" \
    "plugin-runtime-deps" \
    "carbonite" \
    "cron" \
    "flows" \
    "memory" \
    "plugins" \
    "qmd" \
    "sandbox" \
    "session-delivery-queue" \
    "tasks" \
    "telegram" \
    "wiki/main" \
    "openclaw.json.bak-*" \
    "agents/*/sessions/*.bak-*" \
    "agents/*/sessions/*.deleted.*" \
    "agents/*/sessions/*.reset.*" \
    "agents/*/sessions/*.lock" \
    "agents/*/qmd/xdg-cache" \
    "agents/*/qmd/xdg-config" \
    "agents/*/agent/auth-profiles.json" \
    "carbonite/.git-credentials" \
    "carbonite/env.sh" \
    "workspace/.carbonite.bundle.tar" \
    "workspace/.openclaw/workspace-state.json" \
    "workspace/memory/agentmail-last-check.json" \
    "workspace/memory/heartbeat-state.json" \
    "workspace/memory/rss-state" \
    "workspace/memory/rsshub-upstream-state.json" \
    "workspace/memory/wiki-watch") || true

  mapfile -d '' -t untracked_excluded < <(git ls-files -z --others --exclude-standard -- \
    "credentials" \
    "identity" \
    "devices" \
    "exec-approvals.json" \
    ".config-hash" \
    "openclaw.json" \
    "openclaw.json.last-good" \
    "update-check.json" \
    "backups" \
    "completions" \
    "extensions" \
    "logs" \
    "npm" \
    "plugin-runtime-deps" \
    "carbonite" \
    "cron" \
    "flows" \
    "memory" \
    "plugins" \
    "qmd" \
    "sandbox" \
    "session-delivery-queue" \
    "tasks" \
    "telegram" \
    "wiki/main" \
    "openclaw.json.bak-*" \
    "agents/*/sessions/*.bak-*" \
    "agents/*/sessions/*.deleted.*" \
    "agents/*/sessions/*.reset.*" \
    "agents/*/sessions/*.lock" \
    "agents/*/qmd/xdg-cache" \
    "agents/*/qmd/xdg-config" \
    "agents/*/agent/auth-profiles.json" \
    "carbonite/env.sh" \
    "workspace/.carbonite.bundle.tar" \
    "workspace/.openclaw/workspace-state.json" \
    "workspace/memory/agentmail-last-check.json" \
    "workspace/memory/heartbeat-state.json" \
    "workspace/memory/rss-state" \
    "workspace/memory/rsshub-upstream-state.json" \
    "workspace/memory/wiki-watch") || true

  if [ "${#tracked_excluded[@]}" -gt 0 ]; then
    git rm -q -r --cached --ignore-unmatch -- "${tracked_excluded[@]}"
    git update-index --force-remove -- "${tracked_excluded[@]}" 2>/dev/null || true
  fi

  if [ "${#untracked_excluded[@]}" -gt 0 ]; then
    git rm -q -r --cached --ignore-unmatch -- "${untracked_excluded[@]}" || true
  fi
}

# Freeze nested git repos into .bundle files
"$CARBONITE_BIN_DIR/carbonite-bundle" freeze

# Stage only the validated continuity paths, then drop tracked exclusions
stage_preserved_paths
drop_excluded_paths

# Check if there's anything to commit
if git diff --cached --quiet; then
  # Nothing new to commit — but check for unpushed commits from failed pushes
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    UNPUSHED=$(git log --oneline origin/main..HEAD 2>/dev/null | wc -l)
  else
    UNPUSHED=0
  fi
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
git --no-pager diff --cached --stat

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
BACKUP_SCRIPT
chmod +x "$CARBONITE_BIN_DIR/carbonite-backup"

# ── websearch: query OpenShell-hosted SearXNG sidecar ───────────────────────
cat > "$CARBONITE_BIN_DIR/websearch" << 'WEBSEARCH_SCRIPT'
#!/bin/bash
# websearch — query the OpenShell-hosted SearXNG sidecar from inside a sandbox

set -euo pipefail

SEARXNG_URL="${SEARXNG_URL:-http://host.openshell.internal:8888}"
COUNT=5
CATEGORY="general"
QUERY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --count)
      COUNT="$2"
      shift 2
      ;;
    --category)
      CATEGORY="$2"
      shift 2
      ;;
    *)
      QUERY="${QUERY:+$QUERY }$1"
      shift
      ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "Error: No search query provided"
  echo "Usage: websearch <query> [--count N] [--category CATEGORY]"
  exit 1
fi

RESULT=$(python3 -c '
import sys
import urllib.parse
import urllib.request

base_url, query, category = sys.argv[1:4]
params = urllib.parse.urlencode({"q": query, "format": "json", "categories": category})
url = f"{base_url.rstrip("/")}/search?{params}"
with urllib.request.urlopen(url, timeout=15) as response:
    sys.stdout.write(response.read().decode("utf-8"))
' "$SEARXNG_URL" "$QUERY" "$CATEGORY")

python3 -c '
import json, sys

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print("Error: Invalid JSON response")
    sys.exit(1)

results = data.get("results", [])
count = int(sys.argv[2])
query = sys.argv[3]

if not results:
    print(f"No results found for: {query}")
    sys.exit(0)

print(f"Found {len(results)} results for: {query}")
print(f"Showing top {min(count, len(results))}:")
print()

for i, result in enumerate(results[:count], start=1):
    title = result.get("title", "No title")
    url = result.get("url", "")
    content = result.get("content", "No description")
    engines = ", ".join(result.get("engines", []))
    score = result.get("score", 0)
    print(f"[{i}] {title}")
    print(f"    URL: {url}")
    print(f"    {content}")
    print(f"    Engines: {engines} | Score: {score:.1f}")
    print()
' "$RESULT" "$COUNT" "$QUERY"
WEBSEARCH_SCRIPT
chmod +x "$CARBONITE_BIN_DIR/websearch"

# PATH is locked down by the sandbox entrypoint. Export helpers only for the
# current process; future interactive sessions should use absolute helper paths.
export PATH="$CARBONITE_BIN_DIR:$PATH"

# ── Freeze nested repos ────────────────────────────────────────────────────
echo ""
echo "==> Scanning for nested git repos..."
carbonite-bundle status

echo ""
echo "==> Freezing nested git repos into bundles..."
carbonite-bundle freeze

# ── Initialize Carbonite repo ──────────────────────────────────────────────
cd "$CARBONITE_REPO_ROOT"
echo ""
echo "==> Initializing Carbonite repo in $(pwd)..."

if [ "$CONTINUE_MODE" = true ]; then
  echo "    --continue mode: cloning existing history..."
  if [ -f "$CARBONITE_LOCAL_HISTORY_TAR" ]; then
    echo "    Using uploaded local Carbonite history: ${CARBONITE_LOCAL_HISTORY_TAR}"
    HISTORY_TMP="/tmp/carbonite-history.$$"
    rm -rf "$HISTORY_TMP"
    mkdir -p "$HISTORY_TMP"
    tar -xf "$CARBONITE_LOCAL_HISTORY_TAR" -C "$HISTORY_TMP"
    if [ ! -d "$HISTORY_TMP/carbonite-history.git" ]; then
      echo "ERROR: Uploaded Carbonite history archive did not contain carbonite-history.git."
      exit 1
    fi
    mv "$HISTORY_TMP/carbonite-history.git" .git
    rm -rf "$HISTORY_TMP"
    git config --unset core.bare
    git reset HEAD -- . 2>/dev/null || true
    echo "    Existing history preserved ($(git rev-list --count HEAD 2>/dev/null || echo 0) commits)"
  elif run_git clone --bare "${REPO_URL}" /tmp/carbonite-bare.$$ 2>/dev/null; then
    mv /tmp/carbonite-bare.$$ .git
    git config --unset core.bare
    git reset HEAD -- . 2>/dev/null || true
    echo "    Existing history preserved ($(git rev-list --count HEAD 2>/dev/null || echo 0) commits)"
  else
    echo "ERROR: Could not clone existing repo in --continue mode."
    echo "       Verify GitHub auth/network approval first, then discard this sandbox and retry in a fresh one."
    exit 1
  fi

  normalize_origin_remote

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
      MISSING_LIST="/tmp/carbonite-missing.$$"
      git ls-files --deleted > "$MISSING_LIST" 2>/dev/null || true
      sed -n '1,20p' "$MISSING_LIST" | sed 's/^/      /'
      rm -f "$MISSING_LIST"
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
    echo "    Continuing with restored filesystem snapshot and fresh .openclaw repo."
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
  rm -f \
    "$HOME/carbonite-restore.tar" \
    /tmp/carbonite-restore-upload/carbonite-restore.tar \
    /tmp/carbonite-restore-upload/carbonite-restore-helpers.tar

  # ── Stage, commit if needed, push ─────────────────────────────────────────
  # Re-freeze after thaw so the .gitignore-excluded .git dirs don't cause
  # issues, and any new .bundle files reflect current state
  carbonite-bundle freeze

  stage_preserved_paths
  drop_excluded_paths

  if [ "$NO_PUSH_MODE" = true ]; then
    echo ""
    echo "==> Validation mode (--no-push)"
    if git diff --cached --quiet; then
      echo "    No staged restore delta relative to archive history."
    else
      echo "    Staged restore delta preserved locally for inspection:"
      git diff --cached --stat || echo "    WARN: Could not print staged restore delta stat; continuing because this is validation-only output."
    fi
    echo "    Skipping restore commit and remote push."
    echo "    If validation passes later, run ~/.openclaw/carbonite/bin/carbonite-backup manually to create the next archive commit."
    echo ""
    echo "==> Re-thawing nested repos for a usable restored workspace..."
    carbonite-bundle thaw
  elif ! git diff --cached --quiet; then
    git commit -m "carbonite: restored backup ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
    git remote add origin "${REPO_URL}" 2>/dev/null || git remote set-url origin "${REPO_URL}"
    run_git push -u origin main
  else
    echo "    No changes from remote — working tree matches last backup."
    git remote add origin "${REPO_URL}" 2>/dev/null || git remote set-url origin "${REPO_URL}"
    run_git push -u origin main
  fi
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
  run_git push --force -u origin main
fi

echo ""
echo "==> Carbonite initialized successfully!"
echo "    Repo: ${REPO_NAME}"
echo "    Branch: main"
echo "    Tracked files: $(git ls-files | wc -l)"
echo ""
echo "==> Available commands:"
echo "    ~/.openclaw/carbonite/bin/carbonite-backup              # incremental backup"
echo "    ~/.openclaw/carbonite/bin/carbonite-backup 'my message' # custom message"
echo "    ~/.openclaw/carbonite/bin/carbonite-bundle status       # show bundles"
echo "    ~/.openclaw/carbonite/bin/carbonite-bundle freeze       # freeze repos"
echo "    ~/.openclaw/carbonite/bin/carbonite-bundle thaw         # restore repos"
echo "    ~/.openclaw/carbonite/bin/websearch 'your query'        # query SearXNG helper"
echo ""
echo "==> To set up scheduled backups via OpenClaw cron:"
cat <<'CRON_EXAMPLE'
    openclaw cron add \
      --name "Carbonite backup" \
      --cron "0 0,12 * * *" \
      --tz "America/New_York" \
      --session isolated \
      --message "Run this shell command and report the output: ~/.openclaw/carbonite/bin/carbonite-backup" \
      --light-context \
      --channel telegram \
      --to 7948676994
CRON_EXAMPLE
echo ""
