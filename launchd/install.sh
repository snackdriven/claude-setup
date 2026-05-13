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

  cp "$p" "$dst"
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
