#!/usr/bin/env bash
# launchd/install.sh — install personal launchd jobs + wrapper scripts.
#
# Wrappers go to ~/.local/bin/ (outside ~/Desktop/ to avoid TCC restrictions
# on launchd-spawned bash). Plists go to ~/Library/LaunchAgents/.
#
# Idempotent: re-running overwrites the deployed copies and re-bootstraps
# the launchd jobs.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# launchd is macOS-only. On Linux/WSL there's no launchctl / LaunchAgents, so
# the scheduled fleet can't be bootstrapped here. Skip cleanly (exit 0) rather
# than crash — the companion toolstack installs fine via the root ./install.sh.
if [[ "$(uname -s)" != "Darwin" ]]; then
  if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    plat="WSL"
  else
    plat="Linux"
  fi
  echo "→ Detected $plat — skipping launchd job install (macOS-only)."
  echo "  The scheduled jobs use macOS launchd, which doesn't exist on $plat."
  echo "  The wrapper scripts in launchd/bin/ are portable bash — run them by hand,"
  echo "  or wire them into cron / systemd user timers if you want them scheduled."
  echo "  (Most jobs are bound to ~/Desktop/personal paths, so they no-op elsewhere.)"
  exit 0
fi

BIN_DIR="$HOME/.local/bin"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

mkdir -p "$BIN_DIR" "$LAUNCHD_DIR"

echo "→ deploying wrappers to $BIN_DIR/"
for f in "$HERE"/bin/*; do
  name="$(basename "$f")"
  cp "$f" "$BIN_DIR/$name"
  chmod +x "$BIN_DIR/$name"
  echo "  ✓ $name"
done

# memory-keeper-backup runs from ~/mcp-data/memory-keeper-backup/backup.sh
# per its plist — mirror it there too if that path exists.
if [ -d "$HOME/mcp-data/memory-keeper-backup" ] \
   && [ -f "$HERE/bin/memory-keeper-backup.sh" ]; then
  cp "$HERE/bin/memory-keeper-backup.sh" \
     "$HOME/mcp-data/memory-keeper-backup/backup.sh"
  chmod +x "$HOME/mcp-data/memory-keeper-backup/backup.sh"
  echo "  ✓ memory-keeper-backup.sh (mirrored to ~/mcp-data/)"
fi

echo
echo "→ deploying plists to $LAUNCHD_DIR/"
GUI_TARGET="gui/$(id -u)"
for p in "$HERE"/plists/*.plist; do
  name="$(basename "$p")"
  label="${name%.plist}"
  dst="$LAUNCHD_DIR/$name"

  # Unload existing first (ignore "not loaded" errors)
  launchctl bootout "$GUI_TARGET" "$dst" 2>/dev/null || true

  # launchd doesn't expand env vars in plists, so substitute the canonical
  # home for the current user's $HOME (portable across mac accounts).
  sed "s#/Users/kayla#$HOME#g" "$p" > "$dst"
  launchctl bootstrap "$GUI_TARGET" "$dst"
  echo "  ✓ $label"
done

echo
echo "→ active personal launchd jobs:"
launchctl list 2>/dev/null | awk '/com\.snackdriven/ {printf "  %s\n", $0}' || true

echo
echo "Done. Logs land in ~/.local/bin/.<job>.{log,err}."
echo "Edit canonical sources here:"
echo "  $HERE/bin/"
echo "  $HERE/plists/"
echo "Re-run ./install.sh after edits to redeploy."
