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
#   1. Clones the configured carbonite repo to a temp directory on the host via gh
#   2. Packages the restore tree as a tarball (preserves symlinks/layout)
#   3. Uploads the tarball into a writable sandbox tmp directory via openshell sandbox upload
#   4. Cleans up temp directory
#
# After upload, connect to the sandbox and run:
#   mkdir -p ~/.openclaw-data
#   tar -xf /tmp/carbonite-restore-upload/carbonite-restore.tar -C ~/.openclaw-data
#   bash ~/.openclaw-data/carbonite/carbonite-init.sh --continue
#
# Prerequisites:
#   - Sandbox must be running (openshell sandbox list shows it Ready)
#   - GitHub CLI (`gh`) installed and already authenticated on the host
#   - openshell CLI installed on host
#
# Usage:
#   bash carbonite-restore.sh [sandbox-name]
#   CARBONITE_REPO_URL=https://github.com/snarkipus/carbonite-scratch.git \
#     bash carbonite-restore.sh my-assistant
# =============================================================================

set -euo pipefail

SANDBOX_NAME="${1:-my-assistant}"
DEFAULT_REPO_URL="https://github.com/snarkipus/carbonite.git"
REPO_URL="${CARBONITE_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_SLUG="${REPO_URL#https://github.com/}"
REPO_SLUG="${REPO_SLUG%.git}"
TMPDIR="/tmp/carbonite-restore-$$"
UPLOAD_DIR="${TMPDIR}/upload"
ARCHIVE_NAME="carbonite-restore.tar"
ARCHIVE_PATH="${UPLOAD_DIR}/${ARCHIVE_NAME}"
SANDBOX_UPLOAD_DIR="/tmp/carbonite-restore-upload"

echo "==> Carbonite Restore"
echo "    Sandbox: ${SANDBOX_NAME}"
echo "    Repo:    ${REPO_URL}"
echo ""

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh is required on the host for Carbonite restore."
  exit 1
fi

if [ -z "$REPO_SLUG" ] || [ "$REPO_SLUG" = "$REPO_URL" ]; then
  echo "ERROR: CARBONITE_REPO_URL must be a GitHub repo URL (got: ${REPO_URL})."
  exit 1
fi

echo "==> Checking host GitHub CLI auth..."
if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated for GitHub access on the host."
  exit 1
fi

# ── Verify sandbox is running ───────────────────────────────────────────────
echo "==> Checking sandbox status..."
if ! openshell sandbox list 2>/dev/null | grep -q "${SANDBOX_NAME}"; then
  echo "ERROR: Sandbox '${SANDBOX_NAME}' not found or not running."
  echo "       Run 'openshell sandbox list' to check."
  exit 1
fi

# ── Clone repo ──────────────────────────────────────────────────────────────
echo "==> Cloning carbonite to ${TMPDIR}..."
mkdir -p "${TMPDIR}" "${UPLOAD_DIR}"
gh repo clone "$REPO_SLUG" "${TMPDIR}/carbonite" -- --depth 1

# Remove .git directory — Carbonite's own repo state will be re-initialized
rm -rf "${TMPDIR}/carbonite/.git"

# ── Package restore archive ────────────────────────────────────────────────
echo "==> Packaging restore archive..."
tar -cf "${ARCHIVE_PATH}" -C "${TMPDIR}/carbonite" .

# ── Upload to sandbox ──────────────────────────────────────────────────────
echo "==> Uploading to sandbox '${SANDBOX_NAME}'..."
echo "    Source tree: ${TMPDIR}/carbonite/"
echo "    Archive:     ${ARCHIVE_PATH}"
echo "    Result:      ${ARCHIVE_NAME} lands at ${SANDBOX_UPLOAD_DIR}/"
echo ""

if ! openshell sandbox upload "${SANDBOX_NAME}" "${UPLOAD_DIR}" "${SANDBOX_UPLOAD_DIR}"; then
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
echo "    2. Extract:  mkdir -p ~/.openclaw-data && tar -xf ${SANDBOX_UPLOAD_DIR}/${ARCHIVE_NAME} -C ~/.openclaw-data/"
echo "    3. Verify:   ls -la ~/.openclaw-data/carbonite ~/.openclaw-data/carbonite/bin"
echo "    4. Init:     bash ~/.openclaw-data/carbonite/carbonite-init.sh --continue"
echo ""
echo "    The --continue flag will:"
echo "      - Preserve Carbonite git history"
echo "      - Thaw .carbonite.bundle files back to .git dirs"
echo "      - Validate restored nested repos"
echo "      - Install backup & bundle scripts to ~/.openclaw-data/carbonite/bin/"
echo "      - Re-establish push to GitHub"
echo ""
echo "    5. Cron:     bash ~/.openclaw-data/carbonite/carbonite-cron-setup.sh"
echo "    6. Env:      bash ~/.openclaw-data/carbonite/bin/env-setup    # optional helper template"
echo "    7. Test:     ~/.openclaw-data/carbonite/bin/carbonite-backup 'post-restore verification'"
echo ""
