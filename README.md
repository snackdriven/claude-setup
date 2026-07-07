# claude-setup

Personal Claude Code toolstack installer. Pulls each component from GitHub, runs its installer, merges `~/.claude/settings.json` without clobbering anything.

No auto-update — just run it again when you want to pick up changes. All the component installers overwrite files in `~/.claude/` so reinstalling is safe.

## Requirements

`jq`, `git`, and `python3` on PATH. `install.sh` checks for these up front and prints an install hint if any are missing.

- macOS: `brew install jq git python3`
- Debian/Ubuntu (incl. WSL): `sudo apt install jq git python3`

## Platform support

- **macOS** — full stack, including the scheduled `launchd` jobs.
- **Linux / WSL** — the companion toolstack (buddy, statusline, scratch-pad, memory system) installs and runs. The **scheduled `launchd` fleet is macOS-only**: `launchd/install.sh` detects a non-macOS host and skips cleanly instead of erroring. The wrapper scripts in `launchd/bin/` are portable bash if you want to wire them into cron or systemd user timers yourself (note most are bound to `~/Desktop/personal` paths, so they no-op off Kayla's machine). See [`launchd/README.md`](launchd/README.md).

## Usage

```bash
git clone https://github.com/snackdriven/claude-setup.git
cd claude-setup
./install.sh             # full stack
./install.sh companion   # buddy + statusline only
./install.sh --list      # see all profiles
```

## Profiles

| Profile | Components |
|---------|-----------|
| `companion` | better-buddy + claude-statusline |
| `qa` | companion + scratch-pad |
| `full` | qa + operator-core-mini |

## Components

- **[better-buddy](https://github.com/snackdriven/better-buddy)** — persistent companion that lives in the statusline. Tracks affection/hunger, reacts to git events, naps. Interact via `/buddy` in Claude Code.
- **[claude-statusline](https://github.com/snackdriven/claude-statusline)** — multi-region statusline renderer. Shows active ticket + workflow step, context window usage, Spotify now playing, project/branch/dirty count, next meeting.
- **[scratch-pad](https://github.com/snackdriven/scratch-pad)** — operator vault and config sync
- **[operator-core-mini](https://github.com/snackdriven/operator-core-mini)** — three-layer memory system (Backpack / Doctrine / Hoard)

## How it works

1. Clones each component repo at depth 1 into a temp dir
2. Runs each component's installer in profile order
3. Writes one merged `~/.claude/settings.json` at the end

## lib/merge-settings.py

Deep-merges a JSON patch into `~/.claude/settings.json`. Existing keys that aren't in the patch stay untouched.

```bash
python3 lib/merge-settings.py patch.json
```
