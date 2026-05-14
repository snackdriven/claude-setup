#!/usr/bin/env bash
# stale-git-lock-cleanup.sh
#
# Periodic janitor for stale .git/index.lock files in known repos. Removes a lock
# only when ALL of these are true:
#   - lock file exists
#   - lock is older than 5 minutes
#   - no process currently holds the file open (per lsof)
#
# Scheduled by ~/Library/LaunchAgents/com.snackdriven.stale-git-lock-cleanup.plist
# Runs every 15 min.
#
# Logs to ~/.local/bin/.stale-git-lock-cleanup.{log,err}

set -u

JOB_NAME="stale-git-lock-cleanup"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPOS=(
  "$HOME/Desktop/personal"
  "$HOME/bin"
)

TS="$(date '+%Y-%m-%d %H:%M:%S')"
cleaned=0
left_recent=0
left_held=0

for repo in "${REPOS[@]}"; do
  lock="$repo/.git/index.lock"
  [[ ! -f "$lock" ]] && continue

  # Require lock age > 5 minutes (find -mmin +5 means strictly older than 5min)
  if [[ -z $(find "$lock" -mmin +5 2>/dev/null) ]]; then
    echo "[$TS] $repo: lock present but <5min old, leaving"
    left_recent=$((left_recent + 1))
    continue
  fi

  # Require no active process holds it open
  if lsof "$lock" 2>/dev/null | grep -q .; then
    echo "[$TS] $repo: lock held by active process, leaving"
    left_held=$((left_held + 1))
    continue
  fi

  # All checks pass — safe to remove
  rm -f "$lock"
  echo "[$TS] $repo: removed stale lock (age $(find "$lock" -newer "$lock" 2>/dev/null; stat -f '%Sm' "$lock" 2>/dev/null || echo unknown))"
  cleaned=$((cleaned + 1))
done

# Only log a summary when something was touched (keeps the log file lean)
if (( cleaned > 0 || left_held > 0 )); then
  echo "[$TS] summary: cleaned=$cleaned, left-recent=$left_recent, left-held=$left_held"
fi

exit 0
