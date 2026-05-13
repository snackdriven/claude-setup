#!/bin/bash
# pr-touches-atom.sh
#
# Wrapper for scripts/pr-touches-atom.ts so launchd can fire it daily.
# launchd-spawned processes can't execute scripts under ~/Desktop (TCC),
# so this wrapper gets deployed to ~/.local/bin via install.sh and cd's
# into the repo.
#
# Logs to ~/.local/bin/.pr-touches-atom.{log,err}
# Schedule (when wired): daily, ahead of daily-prep at 7:00am, so the
# atom-PR list is fresh when the daily note is generated.

set -euo pipefail

JOB_NAME="pr-touches-atom"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO="$HOME/Desktop/personal"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

echo ""
echo "$LOG_PREFIX --- pr-touches-atom starting ---"

# nvm-managed Node — source nvm so `node` and `npx` are on PATH
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

# 5min cap. Single attempt — gh CLI is local and reliable; no retry needed.
~/.local/bin/with-timeout.sh 300 npx tsx scripts/pr-touches-atom.ts

echo "$LOG_PREFIX --- pr-touches-atom finished ---"
