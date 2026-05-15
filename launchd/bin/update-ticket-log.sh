#!/bin/bash
# Wrapper for scripts/update-ticket-log.sh so launchd can fire it every 30 min.
# launchd has Full Disk Access; cron does not. The source script cds into
# ~/Desktop/personal which cron can't reach.
#
# Logs to ~/.local/bin/.update-ticket-log.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.update-ticket-log.plist
# StartInterval=1800.

set -euo pipefail

JOB_NAME="update-ticket-log"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- update-ticket-log starting ---"

cd "$REPO"
bash "$REPO/scripts/update-ticket-log.sh"

echo "$LOG_PREFIX --- update-ticket-log finished ---"
