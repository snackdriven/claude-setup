#!/bin/bash
# Wrapper for scripts/auto-organize-screengrabs.sh so launchd can fire it hourly.
# launchd has Full Disk Access via System Settings → Privacy & Security; cron
# does not, so the personal/scripts/ source isn't directly callable from cron.
# This wrapper lives at ~/.local/bin and invokes the script via bash.
#
# Logs to ~/.local/bin/.auto-organize-screengrabs.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.auto-organize-screengrabs.plist
# Hourly.

set -euo pipefail

JOB_NAME="auto-organize-screengrabs"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- auto-organize-screengrabs starting ---"

cd "$REPO"
bash "$REPO/scripts/auto-organize-screengrabs.sh"

echo "$LOG_PREFIX --- auto-organize-screengrabs finished ---"
