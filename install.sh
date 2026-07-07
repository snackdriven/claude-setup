#!/usr/bin/env bash
# claude-setup install.sh — orchestrates component installers in dependency order
# Usage: ./install.sh [profile]   (default: full)
#        ./install.sh --list       show available profiles

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"
PROFILE="${1:-full}"

log()  { printf '\033[36m[claude-setup]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m⚠\033[0m %s\n' "$*"; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# --- dependency preflight (portable: macOS + Linux/WSL) ---
missing=()
for dep in jq git python3; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  case "$(uname -s)" in
    Darwin) hint="brew install ${missing[*]}" ;;
    *)      hint="sudo apt install ${missing[*]}   # or your distro's package manager" ;;
  esac
  err "Missing required tools: ${missing[*]}. Install them first, e.g.:  $hint"
fi

if [[ "$PROFILE" == "--list" ]]; then
  log "Available profiles:"
  jq -r '.profiles | to_entries[] | "  \(.key)  —  \(.value.description)"' "$MANIFEST"
  exit 0
fi

if ! jq -e --arg p "$PROFILE" '.profiles[$p]' "$MANIFEST" >/dev/null 2>&1; then
  err "Unknown profile: $PROFILE. Run './install.sh --list' to see options."
fi

components=$(jq -r --arg p "$PROFILE" '.profiles[$p].components[]' "$MANIFEST")

log "Installing profile: $PROFILE"
log "Components: $(echo "$components" | tr '\n' ' ')"
echo ""

mkdir -p "$HOME/.claude"

# --- bootstrap: make ~/.claude a dotclaude checkout if it isn't one ---
DOTCLAUDE_REPO="https://github.com/snackdriven/dotclaude.git"
if [[ ! -d "$HOME/.claude/.git" ]]; then
  if [[ -n "$(ls -A "$HOME/.claude" 2>/dev/null)" ]]; then
    log "wiring dotclaude into existing ~/.claude (non-destructive)…"
    if git -C "$HOME/.claude" init -q -b main \
       && { git -C "$HOME/.claude" remote add origin "$DOTCLAUDE_REPO" 2>/dev/null || git -C "$HOME/.claude" remote set-url origin "$DOTCLAUDE_REPO"; } \
       && git -C "$HOME/.claude" fetch -q origin \
       && git -C "$HOME/.claude" reset -q origin/main; then
      git -C "$HOME/.claude" ls-files -z --deleted | xargs -0 -r -I{} git -C "$HOME/.claude" checkout -- {} 2>/dev/null || true
      ok "dotclaude wired into ~/.claude"
    else
      warn "dotclaude bootstrap failed (auth gh first?) — continuing"
    fi
  else
    git clone -q "$DOTCLAUDE_REPO" "$HOME/.claude" && ok "dotclaude cloned → ~/.claude" || warn "dotclaude clone failed (auth gh first?) — continuing"
  fi
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

install_component() {
  local name="$1"
  local repo installer

  repo=$(jq -r ".components[\"$name\"].repo" "$MANIFEST")
  installer=$(jq -r ".components[\"$name\"].installer" "$MANIFEST")

  log "[$name] cloning $repo …"
  local dest="$WORK_DIR/$name"
  git clone --depth=1 "$repo" "$dest" 2>/dev/null \
    || { warn "[$name] clone failed — skipping"; return; }

  if [[ -f "$dest/$installer" ]]; then
    log "[$name] running $installer …"
    bash "$dest/$installer"
    ok "[$name] done"
  else
    warn "[$name] installer not found: $installer — skipping"
  fi
}

while IFS= read -r comp; do
  install_component "$comp"
done <<< "$components"

# One atomic settings.json write — merge statusLine key
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
STATUS_CMD="bash $HOME/.claude/statusline.sh"

if [[ -f "$SETTINGS" ]]; then
  current=$(jq -r '.statusLine // ""' "$SETTINGS" 2>/dev/null || echo "")
  if [[ "$current" != "$STATUS_CMD" ]]; then
    log "settings.json: writing statusLine …"
    tmp=$(mktemp "${SETTINGS}.tmp.XXXXXX")
    jq --arg cmd "$STATUS_CMD" '.statusLine = $cmd' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    ok "settings.json updated"
  else
    ok "settings.json already correct"
  fi
else
  log "settings.json: creating …"
  jq -n --arg cmd "$STATUS_CMD" '{statusLine: $cmd}' > "$SETTINGS"
  ok "settings.json created"
fi

echo ""
ok "claude-setup complete. Reload Claude Code to activate the statusline."
