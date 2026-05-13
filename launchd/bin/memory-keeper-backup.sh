#!/bin/bash
# Daily backup of mcp-memory-keeper SQLite DB.
# Dumps to text SQL (diffable), commits, pushes to private GH repo.
# Restore: sqlite3 new.db < context.sql
set -euo pipefail

JOB_NAME="memory-keeper-backup"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc "/Users/kayla/mcp-data/memory-keeper-backup/backup.err"; exit $rc' EXIT

DB=~/mcp-data/memory-keeper/context.db
REPO=~/mcp-data/memory-keeper-backup
DUMP="$REPO/context.sql"

# Ensure snackdriven gh account is active before push
gh auth switch --user snackdriven >/dev/null 2>&1 || { echo "FATAL: cannot switch gh to snackdriven — check 'gh auth status'"; exit 1; }

cd "$REPO"

sqlite3 "$DB" ".dump" > "$DUMP"

ITEM_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM context_items;")
DUMP_MB=$(du -m "$DUMP" | awk '{print $1}')
DATE=$(date +%F)

git add context.sql
if git diff --cached --quiet; then
  echo "[$DATE] no changes since last backup"
  exit 0
fi

git commit -m "backup $DATE — $ITEM_COUNT items, ${DUMP_MB}M" --quiet
git push -u origin main --quiet 2>/dev/null || git push --quiet
echo "[$DATE] pushed: $ITEM_COUNT items, ${DUMP_MB}M"
