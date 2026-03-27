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
#   1. Clones the configured carbonite repo to a temp directory on the host
#   2. Packages the restore tree as a tarball (preserves symlinks/layout)
#   3. Uploads the tarball into the sandbox via openshell sandbox upload
#   4. Cleans up temp directory
#
# After upload, connect to the sandbox and run:
#   tar -xf ~/carbonite-restore.tar -C ~
#   GH_PAT=ghp_xxx bash ~/carbonite/carbonite-init.sh --continue
#
# Prerequisites:
#   - Sandbox must be running (openshell sandbox list shows it Ready)
#   - GitHub PAT for clone access
#   - openshell CLI installed on host
#
# Usage:
#   GH_PAT=ghp_xxx bash carbonite-restore.sh [sandbox-name]
#   CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
#     GH_PAT=ghp_xxx bash carbonite-restore.sh my-assistant
#   bash carbonite-restore.sh my-assistant   (will prompt for PAT)
# =============================================================================

set -euo pipefail

SANDBOX_NAME="${1:-my-assistant}"
DEFAULT_REPO_URL="https://github.com/snarkipus/carbonite.git"
REPO_URL="${CARBONITE_REPO_URL:-$DEFAULT_REPO_URL}"
TMPDIR="/tmp/carbonite-restore-$$"
UPLOAD_DIR="${TMPDIR}/upload"
ARCHIVE_NAME="carbonite-restore.tar"
ARCHIVE_PATH="${UPLOAD_DIR}/${ARCHIVE_NAME}"

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

CLONE_URL="${REPO_URL/https:\/\/github.com\//https://snarkipus:${GH_PAT}@github.com/}"

# ── Clone repo ──────────────────────────────────────────────────────────────
echo "==> Cloning carbonite to ${TMPDIR}..."
mkdir -p "${TMPDIR}" "${UPLOAD_DIR}"
git clone --depth 1 "${CLONE_URL}" "${TMPDIR}/carbonite"

# Remove .git directory — Carbonite's own repo state will be re-initialized
rm -rf "${TMPDIR}/carbonite/.git"

# ── Package restore archive ────────────────────────────────────────────────
echo "==> Packaging restore archive..."
tar -cf "${ARCHIVE_PATH}" -C "${TMPDIR}/carbonite" .

# ── Upload to sandbox ──────────────────────────────────────────────────────
echo "==> Uploading to sandbox '${SANDBOX_NAME}'..."
echo "    Source tree: ${TMPDIR}/carbonite/"
echo "    Archive:     ${ARCHIVE_PATH}"
echo "    Result:      ${ARCHIVE_NAME} lands at sandbox root (~/)"
echo ""

if ! openshell sandbox upload "${SANDBOX_NAME}" "${UPLOAD_DIR}"; then
  echo "ERROR: Restore archive upload failed. Sandbox contents may be partial."
  exit 1
fi

# ── Cleanup ─────────────────────────────────────────────────────────────────
echo ""
echo "==> Cleaning up temp directory..."
rm -rf "${TMPDIR}"

echo ""
echo "==> Restore complete!"
echo ""
echo "==> Next steps (inside sandbox):"
echo "    1. Connect:  nemoclaw ${SANDBOX_NAME} connect"
echo "    2. Extract:  tar -xf ~/${ARCHIVE_NAME} -C ~/"
echo "    3. Verify:   ls -la ~/carbonite ~/carbonite/bin"
echo "    4. Init:     GH_PAT=ghp_xxx bash ~/carbonite/carbonite-init.sh --continue"
echo ""
echo "    The --continue flag will:"
echo "      - Preserve Carbonite git history"
echo "      - Thaw .carbonite.bundle files back to .git dirs"
echo "      - Validate restored nested repos"
echo "      - Install backup & bundle scripts to ~/carbonite/bin/"
echo "      - Re-establish push to GitHub"
echo ""
echo "    5. Cron:     bash ~/carbonite/carbonite-cron-setup.sh"
echo "    6. Env:      bash ~/carbonite/bin/env-setup    # optional, recreates ~/.env template"
echo "    7. Test:     carbonite-backup 'post-restore verification'"
echo ""
