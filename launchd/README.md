# launchd

Personal launchd jobs + their wrapper scripts. Disaster-recovery for the scheduled side of the Claude/QA toolstack.

## What's in here

```
bin/      # wrapper scripts. canonical source — edit here, run install.sh to redeploy
plists/   # launchd job definitions. one per scheduled job
install.sh
```

### Wrappers

| Wrapper | Purpose | Scheduled by |
|---|---|---|
| `daily-prep.sh` | Builds today's daily note from Jira + calendar | `com.snackdriven.daily-prep` |
| `mine-bug-patterns.sh` | Weekly NHHA bug-pattern mining (Mondays) | `com.snackdriven.mine-bug-patterns` |
| `check-pass-decay.sh` | Weekly PASS-decay sweep (Mondays) | `com.snackdriven.check-pass-decay` |
| `personal-nightly-commit.sh` | Auto-commit + push for scratch-pad | `com.snackdriven.personal-nightly-commit` |
| `claude-memory-snapshot-refresh.sh` | Nightly export of memory-keeper + ~/.claude/ state | `com.snackdriven.claude-memory-snapshot` |
| `memory-keeper-backup.sh` | Daily sqlite snapshot of memory-keeper DB | `com.snackdriven.memory-keeper-backup` |
| `sync-auto-memory-to-opcomi.sh` | Auto-memory → operator-core-mini sync | (manual / cron) |
| `cron-alert.sh` | Shared failure surface for all jobs above | (called via trap) |
| `with-timeout.sh` | Portable `timeout(1)` shim (perl fork+alarm) | (called by wrappers) |
| `chrome-devtools-manual.sh` | Launches Chrome on :9223 for the `chrome-devtools-manual` MCP | (called by MCP server) |
| `sync-claude-stack` | `git pull --ff-only` across the local Claude dev clones | (manual) |

### Why wrappers exist

launchd-spawned bash can't execute scripts under `~/Desktop/` without TCC Full Disk Access on the script path. `~/.local/bin/` has no TCC restriction, so wrappers live there and `cd` into the repo as their first move.

### Resilience patterns baked in

- Every wrapper has a trap that routes non-zero exits through `cron-alert.sh`
- Network-touching jobs (Jira, gh, git push) are capped with `with-timeout.sh` so launchd never accumulates stuck slots
- Jira-touching weekly jobs (mine-bug-patterns, check-pass-decay) retry once on failure with 30s backoff
- `personal-nightly-commit.sh` self-heals a stale `index.lock` (>1h old, no live git proc)
- `chrome-devtools-manual.sh` kills stale processes bound to :9223 that don't speak DevTools

## Install

```bash
./install.sh
```

Copies `bin/*` → `~/.local/bin/`, plists → `~/Library/LaunchAgents/`, and `launchctl bootstrap`s each job. Idempotent — re-run any time you edit a wrapper or plist.

## Hardcoded paths

Plists reference `/Users/kayla/...` paths directly (launchd doesn't expand env vars). Wrappers use `$HOME` / `~` and are portable. If anyone else ever uses this, the plists need a sed pass over `/Users/kayla` → their `$HOME`.

## Logs

- Per-job: `~/.local/bin/.<job>.{log,err}`
- Shared failure log: `~/.claude/logs/cron-failures.log`
- Daily failure marker (read by `daily-prep`): `~/Desktop/personal/dailies/<today>/.cron-failures.md`
