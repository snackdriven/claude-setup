#!/bin/bash
# check-pass-decay.sh
#
# Wrapper for scripts/check-pass-decay.ts so launchd can fire it weekly.
# launchd-spawned processes can't execute scripts under ~/Desktop (TCC),
# so this wrapper lives at ~/.local/bin and cd's into the repo.
#
# Logs to ~/.local/bin/.check-pass-decay.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.check-pass-decay.plist
# Mondays 6:55am, after mine-bug-patterns and ahead of daily-prep at 7:00am
# so the summary is fresh.

set -euo pipefail

JOB_NAME="check-pass-decay"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- check-pass-decay starting ---"

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  \. "$NVM_DIR/nvm.sh"
fi

cd "$REPO"

if ! command -v npx >/dev/null 2>&1; then
  echo "$LOG_PREFIX ✗ npx not found on PATH — nvm sourcing likely failed" >&2
  exit 1
fi

# 10min cap per attempt, one retry on Jira flake.
for attempt in 1 2; do
  if ~/.local/bin/with-timeout.sh 600 npx tsx scripts/check-pass-decay.ts; then
    break
  fi
  rc=$?
  if [ "$attempt" -lt 2 ]; then
    echo "$LOG_PREFIX attempt $attempt failed (rc=$rc), retrying in 30s" >&2
    sleep 30
  else
    exit "$rc"
  fi
done

echo "$LOG_PREFIX --- check-pass-decay finished ---"
