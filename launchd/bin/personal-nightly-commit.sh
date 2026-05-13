#!/bin/bash
# Nightly auto-commit + push for ~/Desktop/personal scratch-pad.
# Snapshots whatever's in the tree at run time. Skips on rebase/merge in progress.
# No-ops if working tree is clean.
set -euo pipefail

JOB_NAME="personal-nightly-commit"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO=~/Desktop/personal
LOCK="$REPO/.git/index.lock"

# Self-heal stale index.lock (>1h old, no live git proc holding the repo)
if [ -f "$LOCK" ]; then
  AGE_MIN=$(( ($(date +%s) - $(stat -f %m "$LOCK")) / 60 ))
  LIVE_GIT=$(pgrep -f "git.*$REPO" || true)
  if [ "$AGE_MIN" -gt 60 ] && [ -z "$LIVE_GIT" ]; then
    echo "[$(date)] stale index.lock ${AGE_MIN}min old, removing"
    rm -f "$LOCK"
  fi
fi

# Ensure snackdriven gh account is active before push
gh auth switch --user snackdriven >/dev/null 2>&1 || { echo "FATAL: cannot switch gh to snackdriven — check 'gh auth status'"; exit 1; }

cd "$REPO"

# Bail if mid-operation
if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ] || [ -f .git/CHERRY_PICK_HEAD ]; then
  echo "[$(date)] mid-rebase/merge/cherry-pick — skipping"
  exit 0
fi

git add -A
if git diff --cached --quiet; then
  echo "[$(date)] no changes"
  exit 0
fi

STAGED_COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
DATE=$(date +%F)
TIME=$(date +%H:%M)

git commit -m "nightly: $DATE $TIME ($STAGED_COUNT files)" --quiet
# 2min cap on push so a hung network/auth doesn't pin a launchd slot forever.
~/.local/bin/with-timeout.sh 120 git push --quiet
echo "[$(date)] pushed: $STAGED_COUNT files"
