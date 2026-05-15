#!/bin/bash
# Wrapper for scripts/daily-qa-setup-wrapper.sh so launchd can fire it weekday mornings.
# launchd has Full Disk Access; cron does not.
#
# Logs to ~/.local/bin/.daily-qa-setup.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.daily-qa-setup.plist
# Mon-Fri 06:00.

set -euo pipefail

JOB_NAME="daily-qa-setup"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- daily-qa-setup starting ---"

cd "$REPO"
bash "$REPO/scripts/daily-qa-setup-wrapper.sh"

echo "$LOG_PREFIX --- daily-qa-setup finished ---"
