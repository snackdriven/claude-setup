#!/usr/bin/env bash
# claude-setup install.sh — orchestrates component installers in dependency order
# Usage: ./install.sh [profile]     install a named profile (companion|qa|full)
#        ./install.sh --interactive force the interactive picker
#        ./install.sh --list        show available profiles
#
# With no args on a terminal, drops into the interactive picker. With no args
# off a terminal (pipe/CI), defaults to the "companion" profile so nothing hangs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.json"
ARG="${1:-}"

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

if [[ "$ARG" == "--list" ]]; then
  log "Available profiles:"
  jq -r '.profiles | to_entries[] | "  \(.key)  —  \(.value.description)"' "$MANIFEST"
  exit 0
fi

# --- component names, in manifest order (bash 3.2 safe: no mapfile) ---
COMP_NAMES=()
while IFS= read -r _n; do COMP_NAMES+=("$_n"); done < <(jq -r '.components | keys_unsorted[]' "$MANIFEST")

# dedupe a newline list, preserving first-seen order
dedupe() { awk 'NF && !seen[$0]++'; }

# resolve a picker string → newline-separated component names on stdout.
# returns 1 on unrecognized input (caller re-prompts).
#   empty                 → companion profile
#   "all"                 → every component
#   a profile name        → that profile's components
#   space/comma numbers   → components by 1-based index
resolve_selection() {
  local input="$1"
  input="${input//,/ }"
  if [[ -z "${input// /}" ]]; then
    jq -r '.profiles.companion.components[]' "$MANIFEST"; return 0
  fi
  if [[ "$input" == "all" ]]; then
    printf '%s\n' "${COMP_NAMES[@]}"; return 0
  fi
  # single token that names a profile
  if [[ "$input" != *" "* ]] && jq -e --arg p "$input" '.profiles[$p]' "$MANIFEST" >/dev/null 2>&1; then
    jq -r --arg p "$input" '.profiles[$p].components[]' "$MANIFEST"; return 0
  fi
  local tok out=()
  for tok in $input; do
    if [[ "$tok" =~ ^[0-9]+$ ]] && (( tok >= 1 && tok <= ${#COMP_NAMES[@]} )); then
      out+=("${COMP_NAMES[$((tok-1))]}")
    else
      return 1
    fi
  done
  printf '%s\n' "${out[@]}"
}

# --- decide mode ---
MODE="profile"
PROFILE=""
if [[ "$ARG" == "--interactive" ]]; then
  MODE="interactive"
elif [[ -z "$ARG" ]]; then
  if [[ -t 0 ]]; then MODE="interactive"; else PROFILE="companion"; fi
else
  PROFILE="$ARG"
fi

components=""

if [[ "$MODE" == "interactive" ]]; then
  log "Interactive install — pick what to put in ~/.claude."
  echo ""
  for i in "${!COMP_NAMES[@]}"; do
    _desc=$(jq -r --arg k "${COMP_NAMES[$i]}" '.components[$k].description' "$MANIFEST")
    printf '  %d) %-20s — %s\n' "$((i+1))" "${COMP_NAMES[$i]}" "$_desc"
  done
  echo ""
  while :; do
    read -r -p 'Pick components — numbers (e.g. "1 2 5"), a profile (companion/qa/full), or "all". [companion]: ' pick || pick=""
    if components=$(resolve_selection "$pick"); then
      components=$(printf '%s\n' "$components" | dedupe)
      [[ -n "$components" ]] && break
    fi
    warn "didn't catch that — use numbers, a profile name, or \"all\"."
  done

  # env prompts only matter to the statusline; skip entirely otherwise
  if printf '%s\n' "$components" | grep -qxF 'claude-statusline'; then
    # read the key list into an array FIRST — otherwise the inner `read` below
    # would steal from the jq process substitution instead of the user's input
    ENV_KEYS=()
    while IFS= read -r _k; do ENV_KEYS+=("$_k"); done < <(jq -r '.env | keys_unsorted[]' "$MANIFEST")
    if [[ ${#ENV_KEYS[@]} -gt 0 ]]; then
      echo ""
      log "statusline settings (Enter keeps the default):"
      for _key in "${ENV_KEYS[@]}"; do
        _def=$(jq -r --arg k "$_key" '.env[$k].default' "$MANIFEST")
        read -r -p "$_key [$_def]: " _val || _val=""
        export "$_key=${_val:-$_def}"
      done
    fi
  fi

  echo ""
  log "Selected: $(printf '%s ' $components)"
  read -r -p 'Install these into ~/.claude? [Y/n]: ' confirm || confirm=""
  confirm=$(printf '%s' "$confirm" | tr '[:upper:]' '[:lower:]')
  case "$confirm" in
    n|no) log "aborted — nothing installed."; exit 0 ;;
  esac
else
  if ! jq -e --arg p "$PROFILE" '.profiles[$p]' "$MANIFEST" >/dev/null 2>&1; then
    err "Unknown profile: $PROFILE. Run './install.sh --list' to see options."
  fi
  components=$(jq -r --arg p "$PROFILE" '.profiles[$p].components[]' "$MANIFEST" | dedupe)
  log "Installing profile: $PROFILE"
fi

log "Components: $(printf '%s ' $components)"
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
  [[ -n "$comp" ]] && install_component "$comp"
done <<< "$components"

# One atomic settings.json write — merge statusLine key
mkdir -p "$HOME/.claude"
SETTINGS="$HOME/.claude/settings.json"
STATUS_CMD="bash $HOME/.claude/statusline.sh"

if [[ -f "$SETTINGS" ]]; then
  current=$(jq -r '.statusLine.command // .statusLine // ""' "$SETTINGS" 2>/dev/null || echo "")
  if [[ "$current" != "$STATUS_CMD" ]]; then
    log "settings.json: writing statusLine …"
    tmp=$(mktemp "${SETTINGS}.tmp.XXXXXX")
    jq --arg cmd "$STATUS_CMD" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    ok "settings.json updated"
  else
    ok "settings.json already correct"
  fi
else
  log "settings.json: creating …"
  jq -n --arg cmd "$STATUS_CMD" '{statusLine: {type:"command", command:$cmd}}' > "$SETTINGS"
  ok "settings.json created"
fi

echo ""
ok "claude-setup complete. Reload Claude Code to activate the statusline."
