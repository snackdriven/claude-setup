#!/bin/bash
# Nightly refresh of claude-memory-snapshot repo.
# Re-runs the three exports (memory-keeper, backpack, claude-state), commits, pushes.
set -euo pipefail

JOB_NAME="claude-memory-snapshot"
trap 'rc=$?; [ $rc -ne 0 ] && ~/.local/bin/cron-alert.sh "'"$JOB_NAME"'" $rc; exit $rc' EXIT

REPO=~/Desktop/projects/claude-memory-snapshot
DB=~/mcp-data/memory-keeper/context.db

# Ensure snackdriven gh account is active before push
gh auth switch --user snackdriven >/dev/null 2>&1 || { echo "FATAL: cannot switch gh to snackdriven — check 'gh auth status'"; exit 1; }

cd "$REPO"

# --- 1. memory-keeper (Python — sqlite3 -json CLI is pathologically slow) ---
rm -rf memory-keeper
mkdir -p memory-keeper/by-channel

python3 - "$DB" "$REPO/memory-keeper" <<'PY'
import sqlite3, json, os, re, sys
db_path, out_dir = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

rows = conn.execute(
    "SELECT id, session_id, key, value, category, priority, metadata, channel, "
    "created_at, updated_at FROM context_items ORDER BY channel, created_at"
).fetchall()

# Full JSON dump
with open(os.path.join(out_dir, 'context_items.json'), 'w') as f:
    json.dump([dict(r) for r in rows], f, indent=2)

# Channel summary
channels = {}
for r in rows:
    channels.setdefault(r['channel'], []).append(r)

with open(os.path.join(out_dir, 'channels.tsv'), 'w') as f:
    for ch, items in sorted(channels.items(), key=lambda x: -len(x[1])):
        f.write(f"{ch}\t{len(items)}\n")

# Per-channel markdown
by_channel_dir = os.path.join(out_dir, 'by-channel')
for ch, items in channels.items():
    safe = re.sub(r'[/\s]', '_', ch)[:100]
    with open(os.path.join(by_channel_dir, f'{safe}.md'), 'w') as f:
        f.write(f"# Channel: {ch}\n\n")
        for r in items:
            f.write(f"## {r['key']}\n\n")
            f.write(f"**Category:** {r['category'] or '(none)'} | **Priority:** {r['priority'] or '(none)'} | **Created:** {r['created_at']}\n\n")
            f.write(f"{r['value']}\n\n---\n\n")

print(f"memory-keeper: {len(rows)} items, {len(channels)} channels", file=sys.stderr)
PY

TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM context_items;")
CHANNELS=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT channel) FROM context_items;")

# --- 2. backpack ---
rm -rf backpack
mkdir -p backpack/raw backpack/entries

cp ~/Desktop/personal/backpack.json backpack/raw/personal-backpack.json 2>/dev/null || true
cp ~/Desktop/platform/backpack.json backpack/raw/platform-backpack.json 2>/dev/null || true
cp -R ~/.operator-core/backpack backpack/raw/operator-core-backpack 2>/dev/null || true

python3 - "$REPO/backpack/entries" <<'PY'
import json, os, re, sys
out_dir = sys.argv[1]
src = os.path.expanduser('~/Desktop/personal/backpack.json')
if not os.path.exists(src):
    sys.exit(0)
with open(src) as f: data = json.load(f)
configs, entries = {}, {}
for k, v in data.items():
    (configs if k.startswith('_config:') else entries)[k] = v
with open(os.path.join(out_dir, '_config.json'), 'w') as f:
    json.dump({k: (json.loads(v) if isinstance(v, str) and v[:1] in '{[' else v) for k, v in configs.items()}, f, indent=2)
for k, v in entries.items():
    safe = re.sub(r'[^a-zA-Z0-9._-]', '_', k)[:200]
    with open(os.path.join(out_dir, f'{safe}.md'), 'w') as f:
        f.write(f'# {k}\n\n')
        if isinstance(v, str):
            try:
                parsed = json.loads(v)
                f.write('```json\n' + json.dumps(parsed, indent=2) + '\n```\n')
            except (json.JSONDecodeError, TypeError):
                f.write(v)
        else:
            f.write('```json\n' + json.dumps(v, indent=2) + '\n```\n')
PY

# --- 3. claude-state ---
rm -rf claude-state
mkdir -p claude-state

cp -R ~/.claude/projects/-Users-kayla-Desktop-personal/memory claude-state/01-project-memory
mkdir -p claude-state/02-top-level-memory
cp ~/.claude/memory/*.md claude-state/02-top-level-memory/ 2>/dev/null || true
cp ~/.claude/CLAUDE.md claude-state/03-global-CLAUDE.md
cp -R ~/.claude/personality claude-state/04-personality
cp -R ~/.claude/skills claude-state/05-skills
cp -R ~/.claude/agents claude-state/06-agents
cp -R ~/.claude/commands claude-state/07-commands
cp ~/.claude/buddy.json claude-state/08-buddy.json

# Strip any nested .git dirs that would otherwise become broken submodules
find claude-state -name ".git" -type d -mindepth 2 -exec rm -rf {} + 2>/dev/null || true

PROJ_MEM=$(find claude-state/01-project-memory -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')

# --- 4. commit + push ---
git add -A
if git diff --cached --quiet; then
  echo "[$(date)] no changes"
  exit 0
fi

DIFF_COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
DATE=$(date +%F)
TIME=$(date +%H:%M)

git commit -m "snapshot $DATE $TIME — mk:$TOTAL/$CHANNELS, pm:$PROJ_MEM ($DIFF_COUNT files)" --quiet
# 2min cap on push so a hung network/auth doesn't pin a launchd slot forever.
~/.local/bin/with-timeout.sh 120 git push --quiet
echo "[$(date)] pushed: $DIFF_COUNT files (mk:$TOTAL items/$CHANNELS channels, pm:$PROJ_MEM files)"
