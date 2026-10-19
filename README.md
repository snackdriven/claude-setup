# claude-setup

The terminal acquired a buddy, a statusline, and a growing pile of tools. Setting them up by hand got old.

This is my Claude Code toolstack installer. Pick a profile or individual components, and it fetches them from GitHub and runs the available installers.

Updates are manual: run it again when you want newer component versions. Installers can overwrite their own files in `~/.claude/`; keep local edits backed up. The final settings write sets `statusLine` while preserving other top-level keys.

## Requirements

`jq`, `git`, and `python3` on PATH. `install.sh` checks for these up front and prints an install hint if any are missing.

- macOS: `brew install jq git python3`
- Debian/Ubuntu (incl. WSL): `sudo apt install jq git python3`

Some components require access to private repositories. A failed clone is reported and skipped, so a completed run does not mean every selected component installed.

## Platform support

- **macOS:** companion installers and the separate scheduled `launchd` jobs.
- **Linux / WSL:** companion installers. The scheduled jobs use macOS-only `launchd`; `launchd/install.sh` skips other platforms. The wrappers in `launchd/bin/` are portable Bash, but most use personal `~/Desktop/personal` paths and do nothing elsewhere until configured. See [`launchd/README.md`](launchd/README.md) before wiring them into cron or systemd user timers.

## Usage

```bash
git clone https://github.com/snackdriven/claude-setup.git
cd claude-setup
./install.sh             # interactive picker in a terminal; companion otherwise
./install.sh companion   # commands + buddy + statusline
./install.sh full        # select every component in the full profile
./install.sh --list      # see all profiles
```

The interactive picker accepts component numbers, a profile name, or `all`, then asks for confirmation before installing. With no argument outside a terminal, the installer selects `companion`.

## Profiles

| Profile | Components |
|---------|-----------|
| `companion` | claude-commands + better-buddy + claude-statusline |
| `qa` | companion + scratch-pad |
| `full` | qa + operator-core-mini |

These are selections, not a guarantee that each component installs. The current manifest has no installer for `scratch-pad` or `operator-core-mini`; both are reported as missing an installer and skipped. The temporary clones are removed when the script exits. The manifest identifies `scratch-pad` as a separate plugin installation.

## Components

- **claude-commands:** personal command and agent library.
- **[better-buddy](https://github.com/snackdriven/better-buddy):** a statusline companion that tracks affection and hunger, reacts to git events, and naps. Interact via `/buddy` in Claude Code.
- **[claude-statusline](https://github.com/snackdriven/claude-statusline):** active ticket and workflow step, context usage, Spotify now-playing, project and branch status, and the next meeting.
- **[scratch-pad](https://github.com/snackdriven/scratch-pad):** operator vault and config sync; requires separate installation.
- **[operator-core-mini](https://github.com/snackdriven/operator-core-mini):** three-layer memory system (Backpack / Doctrine / Hoard); no installer in the current manifest.

## How it works

1. Tries to bootstrap `~/.claude` as a `dotclaude` checkout if it is not already a Git checkout. A bootstrap failure is reported and the script continues.
2. Clones each selected component at depth 1 into a temporary directory.
3. Runs available installers in profile order, reporting skipped components.
4. Sets the statusline command in `~/.claude/settings.json` and removes the temporary clones on exit.

## lib/merge-settings.py

A separate helper for applying a JSON patch to `~/.claude/settings.json`. It merges nested objects and preserves keys absent from the patch; patched scalar values and ordinary lists replace existing values. Hook-shaped lists have special append/deduplication handling.

```bash
python3 lib/merge-settings.py patch.json
```
