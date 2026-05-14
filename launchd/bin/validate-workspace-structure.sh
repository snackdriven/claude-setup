#!/bin/bash
# Wrapper for scripts/validate-workspace-structure.sh so launchd can fire it nightly.
# launchd has Full Disk Access via System Settings → Privacy & Security; cron
# does not, so the personal/scripts/ source isn't directly callable from cron.
# This wrapper lives at ~/.local/bin and invokes the script via bash.
#
# Logs to ~/.local/bin/.validate-workspace-structure.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.validate-workspace-structure.plist
# Daily 23:00.

set -euo pipefail

JOB_NAME="validate-workspace-structure"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- validate-workspace-structure starting ---"

cd "$REPO"
bash "$REPO/scripts/validate-workspace-structure.sh"

echo "$LOG_PREFIX --- validate-workspace-structure finished ---"
