#!/usr/bin/env bash
# Wrapper for the auto-memory → op-co-mi sync.
# Lives in ~/.local/bin/ per feedback-launchd-fda-script-location.md
# (launchd-spawned bash can't execute scripts under ~/Desktop without TCC FDA
# on the script path; ~/.local/bin has no TCC restriction).

set -u

JOB_NAME="opcomi-sync"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc "$LOG"; exit $rc' EXIT

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/opcomi-sync.log"

echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"
# Pin brew python3 — launchd has minimal PATH and `/usr/bin/env python3` resolves
# to system /usr/bin/python3 (3.9, no yaml). Brew python has PyYAML installed.
PYTHON_BIN=$(/usr/bin/which python3)
if [ -x /opt/homebrew/bin/python3 ]; then PYTHON_BIN=/opt/homebrew/bin/python3; fi
"$PYTHON_BIN" "$HOME/Desktop/personal/scripts/sync-auto-memory-to-opcomi.py" >> "$LOG" 2>&1
RC=$?
echo "exit=$RC" >> "$LOG"
echo >> "$LOG"
exit $RC
