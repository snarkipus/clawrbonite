#!/bin/bash
# =============================================================================
# carbonite-cron-setup.sh — Register Carbonite backup as an OpenClaw cron job
# =============================================================================
# Run this INSIDE the sandbox after carbonite-init.sh has completed.
#
# Creates a recurring cron job that runs carbonite-backup every 4 hours.
# The job runs in an isolated session with lightweight context to minimize
# token burn. carbonite-backup automatically freezes nested repos before
# staging.
#
# IDEMPOTENT: Checks for existing "Carbonite backup" job before adding.
# If found, skips creation and shows current job state.
# =============================================================================

set -euo pipefail

JOB_NAME="Carbonite backup"

echo "==> Checking for existing Carbonite cron job..."

# Check if a job with this name already exists
# openclaw cron list output format varies, but job names are quoted in output
if openclaw cron list 2>/dev/null | grep -qi "carbonite backup"; then
  echo "    Carbonite backup job already exists:"
  echo ""
  openclaw cron list 2>/dev/null | grep -i -A5 "carbonite"
  echo ""
  echo "==> Skipping creation (job already registered)."
  echo "    To recreate: openclaw cron rm <job-id> && bash carbonite-cron-setup.sh"
  echo "    To test now:  openclaw cron run <job-id>"
  exit 0
fi

echo "==> No existing job found. Creating..."

openclaw cron add \
  --name "$JOB_NAME" \
  --cron "0 */4 * * *" \
  --tz "America/New_York" \
  --session isolated \
  --message "Run this shell command and report the output: carbonite-backup" \
  --light-context

echo ""
echo "==> Verifying cron job..."
openclaw cron list

echo ""
echo "==> To test immediately:"
echo "    openclaw cron run <job-id>"
echo ""
echo "==> To check run history:"
echo "    openclaw cron runs --id <job-id>"
echo ""
echo "==> To modify schedule (e.g., every 6 hours):"
echo "    openclaw cron edit <job-id>"
echo ""
echo "==> Note: Cron jobs persist in ~/.openclaw/cron/jobs.json"
echo "    They survive gateway restarts but NOT sandbox rebuilds."
echo "    After a rebuild, re-run this script."
echo ""
