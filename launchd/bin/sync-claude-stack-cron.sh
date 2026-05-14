#!/usr/bin/env bash
# Wrapper around sync-claude-stack for launchd. Logs run to ~/.claude/logs/.
# sync-claude-stack lives at ~/.local/bin/sync-claude-stack.

set -u

JOB_NAME="sync-claude-stack"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc "$LOG"; exit $rc' EXIT

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/sync-claude-stack.log"

echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
/bin/bash "$HOME/.local/bin/sync-claude-stack" >> "$LOG" 2>&1
RC=$?
echo "exit=$RC" >> "$LOG"
echo >> "$LOG"
exit $RC
