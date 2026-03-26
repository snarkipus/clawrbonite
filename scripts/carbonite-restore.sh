#!/bin/bash
# =============================================================================
# carbonite-restore.sh — Restore sandbox state from Carbonite backup
# =============================================================================
# Run this on the HOST after a sandbox rebuild to restore backed-up state.
#
# PRECONDITION: Restore assumes a clean/disposable sandbox. The target
# /sandbox directory should be in its default post-creation state. This
# script uploads over it without clearing first — in a fresh sandbox
# this is deterministic. Do NOT run against a sandbox with meaningful
# uncommitted work.
#
# What it does:
#   1. Clones carbonite repo to a temp directory on the host
#   2. Uploads contents into the sandbox via openshell sandbox upload
#   3. Cleans up temp directory
#
# After upload, connect to the sandbox and run:
#   GH_PAT=ghp_xxx bash ~/carbonite-init.sh --continue
#
# Prerequisites:
#   - Sandbox must be running (openshell sandbox list shows it Ready)
#   - GitHub PAT for clone access
#   - openshell CLI installed on host
#
# Usage:
#   GH_PAT=ghp_xxx bash carbonite-restore.sh [sandbox-name]
#   bash carbonite-restore.sh my-assistant   (will prompt for PAT)
# =============================================================================

set -euo pipefail

SANDBOX_NAME="${1:-my-assistant}"
REPO_URL="https://github.com/snarkipus/carbonite.git"
TMPDIR="/tmp/carbonite-restore-$$"

echo "==> Carbonite Restore"
echo "    Sandbox: ${SANDBOX_NAME}"
echo "    Repo:    ${REPO_URL}"
echo ""

# ── Verify sandbox is running ───────────────────────────────────────────────
echo "==> Checking sandbox status..."
if ! openshell sandbox list 2>/dev/null | grep -q "${SANDBOX_NAME}"; then
  echo "ERROR: Sandbox '${SANDBOX_NAME}' not found or not running."
  echo "       Run 'openshell sandbox list' to check."
  exit 1
fi

# ── GitHub PAT ──────────────────────────────────────────────────────────────
if [ -z "${GH_PAT:-}" ]; then
  read -rsp "GitHub PAT (repo scope): " GH_PAT
  echo
fi

CLONE_URL="https://snarkipus:${GH_PAT}@github.com/snarkipus/carbonite.git"

# ── Clone repo ──────────────────────────────────────────────────────────────
echo "==> Cloning carbonite to ${TMPDIR}..."
mkdir -p "${TMPDIR}"
git clone --depth 1 "${CLONE_URL}" "${TMPDIR}/carbonite"

# Remove .git directory — Carbonite's own repo state will be re-initialized
rm -rf "${TMPDIR}/carbonite/.git"

# ── Upload to sandbox ──────────────────────────────────────────────────────
echo "==> Uploading to sandbox '${SANDBOX_NAME}'..."
echo "    Source: ${TMPDIR}/carbonite/"
echo "    Dest:   /sandbox/"
echo ""

cd "${TMPDIR}/carbonite"
for item in * .[!.]*; do
  [ -e "$item" ] || continue
  echo "    Uploading: $item"
  openshell sandbox upload "${SANDBOX_NAME}" "$item" "/sandbox/$item" 2>/dev/null || {
    echo "    WARN: Failed to upload $item (may already exist or be read-only)"
  }
done

# ── Cleanup ─────────────────────────────────────────────────────────────────
echo ""
echo "==> Cleaning up temp directory..."
rm -rf "${TMPDIR}"

echo ""
echo "==> Restore complete!"
echo ""
echo "==> Next steps (inside sandbox):"
echo "    1. Connect:  nemoclaw ${SANDBOX_NAME} connect"
echo "    2. Verify:   ls -la ~/"
echo "    3. Init:     GH_PAT=ghp_xxx bash ~/carbonite-init.sh --continue"
echo ""
echo "    The --continue flag will:"
echo "      - Preserve Carbonite git history"
echo "      - Thaw .carbonite.bundle files back to .git dirs"
echo "      - Validate restored nested repos"
echo "      - Install backup & bundle scripts to ~/bin/"
echo "      - Re-establish push to GitHub"
echo ""
echo "    4. Cron:     bash ~/carbonite-cron-setup.sh"
echo "    5. Test:     carbonite-backup 'post-restore verification'"
echo ""
