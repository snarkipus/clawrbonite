#!/bin/bash
# =============================================================================
# carbonite-host-sync.sh — Push sandbox Carbonite history from the host
# =============================================================================
# Run this on the HOST when sandbox git transport cannot authenticate directly.
# It exports the sandbox's ~/.openclaw git history as a bundle, downloads it, and
# fast-forwards the configured Carbonite archive repo from host-side GitHub auth.
#
# Usage:
#   bash carbonite-host-sync.sh [sandbox-name]
# =============================================================================

set -euo pipefail

SANDBOX_NAME="${1:-my-assistant}"
DEFAULT_REPO_URL="https://github.com/snarkipus/carbonite.git"
REPO_URL="${CARBONITE_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_SLUG="${REPO_URL#https://github.com/}"
REPO_SLUG="${REPO_SLUG%.git}"
BRANCH="${CARBONITE_BRANCH:-main}"
TMPDIR="/tmp/carbonite-host-sync-$$"
SANDBOX_BUNDLE="/sandbox/.openclaw/carbonite/carbonite-host-sync-$$.bundle"
HOST_BUNDLE="${TMPDIR}/carbonite.bundle"
HOST_REPO="${TMPDIR}/carbonite"

cleanup() {
  openshell sandbox exec -n "$SANDBOX_NAME" -- rm -f "$SANDBOX_BUNDLE" >/dev/null 2>&1 || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "==> Carbonite host sync"
echo "    Sandbox: ${SANDBOX_NAME}"
echo "    Repo:    ${REPO_URL}"
echo "    Branch:  ${BRANCH}"
echo ""

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh is required on the host for Carbonite host sync."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated for GitHub access on the host."
  exit 1
fi

mkdir -p "$TMPDIR"

echo "==> Creating sandbox git bundle..."
openshell sandbox exec -n "$SANDBOX_NAME" -- sh -lc \
  "cd \"\$HOME/.openclaw\" && mkdir -p \"\$(dirname '${SANDBOX_BUNDLE}')\" && test -d .git && git rev-parse --verify ${BRANCH} >/dev/null && git bundle create '${SANDBOX_BUNDLE}' --all"

echo "==> Downloading sandbox bundle..."
openshell sandbox download "$SANDBOX_NAME" "$SANDBOX_BUNDLE" "$HOST_BUNDLE"

echo "==> Cloning archive on host..."
gh repo clone "$REPO_SLUG" "$HOST_REPO" -- --branch "$BRANCH"

echo "==> Importing sandbox branch from bundle..."
git -C "$HOST_REPO" fetch "$HOST_BUNDLE" "refs/heads/${BRANCH}:refs/remotes/sandbox/${BRANCH}"

echo "==> Fast-forwarding host checkout..."
git -C "$HOST_REPO" merge --ff-only "refs/remotes/sandbox/${BRANCH}"

echo "==> Pushing archive from host..."
git -C "$HOST_REPO" push origin "$BRANCH"

echo ""
echo "==> Carbonite host sync complete."
