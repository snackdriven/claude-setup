# claude-setup

One installer for the full Claude Code companion stack.

## Profiles

| Profile | Components |
|---------|-----------|
| `companion` | better-buddy + claude-statusline |
| `qa` | companion + scratch-pad |
| `full` | qa + operator-core-mini |

## Usage

```bash
# Install full stack
./install.sh

# Install a specific profile
./install.sh companion
./install.sh qa

# List profiles
./install.sh --list
```

## What it does

1. Clones each component repo at depth 1
2. Runs each component's installer in dependency order
3. Writes a single merged `~/.claude/settings.json` (no stomping)

## Components

- **[better-buddy](https://github.com/snackdriven/better-buddy)** — virtual companion + buddy-status.sh shim
- **[claude-statusline](https://github.com/snackdriven/claude-statusline)** — multi-region statusline renderer
- **[scratch-pad](https://github.com/snackdriven/scratch-pad)** — operator vault + config sync
- **[operator-core-mini](https://github.com/snackdriven/operator-core-mini)** — three-layer memory system

## lib/merge-settings.py

Merges a JSON patch into `~/.claude/settings.json` without clobbering existing keys. Used internally by `install.sh`.

```bash
python3 lib/merge-settings.py patch.json
```
