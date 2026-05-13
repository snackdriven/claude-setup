#!/bin/bash
# daily-prep.sh
#
# Wrapper for scripts/daily-prep.ts so launchd can fire it.
# launchd-spawned processes can't execute scripts under ~/Desktop (TCC),
# so this wrapper lives at ~/.local/bin and cd's into the repo.
#
# Logs to ~/.local/bin/.daily-prep.{log,err}
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.daily-prep.plist

set -euo pipefail

JOB_NAME="daily-prep"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- daily-prep starting ---"

# nvm-managed Node — source nvm so `node` and `npx` are on PATH
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  \. "$NVM_DIR/nvm.sh"
fi

# Make sure we use the work gh account (script queries ChorusInnovations/platform)
if command -v gh >/dev/null 2>&1; then
  gh auth switch -u kayla-at-chorus 2>/dev/null || true
fi

cd "$REPO"

if ! command -v npx >/dev/null 2>&1; then
  echo "$LOG_PREFIX ✗ npx not found on PATH — nvm sourcing likely failed" >&2
  exit 1
fi

# Run the actual script. It's idempotent (won't overwrite existing daily note),
# so this is safe to re-run multiple times in a day. 5min cap so launchd never
# ends up with a zombie process if Jira/gh hangs.
~/.local/bin/with-timeout.sh 300 npx tsx scripts/daily-prep.ts

echo "$LOG_PREFIX --- daily-prep finished ---"
