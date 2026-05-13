#!/usr/bin/env bash
# health-check.sh — one-shot status across the dev environment.
#
# Reports: gh active account, repo cleanliness across personal dev clones,
# MCP connection status, launchd schedule state, recent cron failures,
# whether today's daily note exists.
#
# Not destructive. Safe to run any time. ~3 seconds.

set -u

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$1"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
dim()  { printf '  \033[2m%s\033[0m\n' "$1"; }

bold "─── gh ───"
gh auth status 2>&1 | awk '
  /Logged in to github.com account/ { sub(/^.*account /, ""); sub(/ \(.*$/, ""); acct=$0 }
  /Active account: true/  { print "  ✓ active: " acct }
  /Active account: false/ { print "  · inactive: " acct }
'

bold "─── repos ───"
for d in ~/Desktop/personal \
         ~/Desktop/projects/claude-setup \
         ~/Desktop/projects/claude-memory-snapshot \
         ~/Desktop/projects/operator-core-mini \
         ~/Desktop/projects/better-buddy \
         ~/Desktop/projects/claude-statusline \
         ~/Desktop/projects/qa-brain; do
  [ -d "$d/.git" ] || continue
  cd "$d"
  name=$(basename "$d")
  head=$(git rev-parse --short HEAD 2>/dev/null)
  acct=$(git remote get-url origin 2>/dev/null | sed -E 's|.*[/:]([^/]+)/[^/]+(\.git)?$|\1|')
  behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$dirty" -gt 0 ]; then
    warn "$(printf '%-26s head=%s acct=%s behind=%s dirty=%s' "$name" "$head" "$acct" "$behind" "$dirty")"
  else
    ok   "$(printf '%-26s head=%s acct=%s behind=%s clean'    "$name" "$head" "$acct" "$behind")"
  fi
done

bold "─── MCP ───"
if command -v claude >/dev/null 2>&1; then
  claude mcp list 2>&1 | grep -E '✓|✗|Failed|Needs' | sed 's/^/  /'
else
  dim "claude CLI not on PATH"
fi

bold "─── launchd (com.snackdriven.*) ───"
launchctl list 2>/dev/null | awk '
  /com\.snackdriven/ {
    if ($2 == "0") printf "  ✓ %s\n", $3
    else           printf "  ✗ %s (last exit=%s)\n", $3, $2
  }
'

bold "─── cron-failures since last check ───"
FAILLOG=~/.claude/logs/cron-failures.log
if [ -s "$FAILLOG" ]; then
  err "$(wc -l < "$FAILLOG" | tr -d ' ') lines in $FAILLOG"
  dim "tail:"
  tail -5 "$FAILLOG" | sed 's/^/    /'
else
  ok "no failures logged"
fi

bold "─── today's daily note ───"
today=$(date +%F)
if [ -f ~/Desktop/personal/dailies/$today/$today.md ]; then
  ok "dailies/$today/$today.md ($(wc -l < ~/Desktop/personal/dailies/$today/$today.md | tr -d ' ') lines)"
else
  err "dailies/$today/$today.md missing — daily-prep didn't run"
fi

bold "─── last cron failure marker (real-time) ───"
MARKER=~/.claude/.last-cron-failure.json
if [ -f "$MARKER" ]; then
  warn "$(cat "$MARKER")"
else
  ok "no fresh failure marker"
fi
echo
