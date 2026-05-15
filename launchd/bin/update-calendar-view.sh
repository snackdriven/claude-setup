#!/bin/bash
# Wrapper for scripts/update-calendar-view.sh so launchd can fire it
# at :01 of every 4-hour slot (1 min after .ics refresh at :00).
# launchd has Full Disk Access; cron does not.
#
# Logs to ~/.local/bin/.update-calendar-view.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.update-calendar-view.plist
# 00:01, 04:01, 08:01, 12:01, 16:01, 20:01.

set -euo pipefail

JOB_NAME="update-calendar-view"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- update-calendar-view starting ---"

cd "$REPO"
bash "$REPO/scripts/update-calendar-view.sh"

echo "$LOG_PREFIX --- update-calendar-view finished ---"
