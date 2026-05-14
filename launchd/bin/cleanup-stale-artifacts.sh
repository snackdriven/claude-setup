#!/bin/bash
# Wrapper for scripts/cleanup-stale-artifacts.sh so launchd can fire it weekly.
# launchd has Full Disk Access via System Settings → Privacy & Security; cron
# does not, so the personal/scripts/ source isn't directly callable from cron.
# This wrapper lives at ~/.local/bin and invokes the script via bash.
#
# Logs to ~/.local/bin/.cleanup-stale-artifacts.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.cleanup-stale-artifacts.plist
# Sundays 2:00 AM.

set -euo pipefail

JOB_NAME="cleanup-stale-artifacts"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- cleanup-stale-artifacts starting ---"

cd "$REPO"
bash "$REPO/scripts/cleanup-stale-artifacts.sh"

echo "$LOG_PREFIX --- cleanup-stale-artifacts finished ---"
