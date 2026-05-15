#!/bin/bash
# Wrapper for scripts/daily-summary.sh so launchd can fire it nightly.
# launchd has Full Disk Access; cron does not. The source script cds into
# ~/Desktop/personal which cron can't reach.
#
# Logs to ~/.local/bin/.daily-summary.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.daily-summary.plist
# Daily 22:00.

set -euo pipefail

JOB_NAME="daily-summary"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- daily-summary starting ---"

cd "$REPO"
bash "$REPO/scripts/daily-summary.sh"

echo "$LOG_PREFIX --- daily-summary finished ---"
