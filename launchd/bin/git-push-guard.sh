#!/usr/bin/env bash
# git-push-guard.sh — pre-flight gh-account check before git push.
#
# Compares the active gh account against the account in `origin`'s URL.
# Refuses to push if they don't match. Removes the "wait, am I on chorus
# or snackdriven right now?" foot-gun.
#
# Usage: ~/.local/bin/git-push-guard.sh [git-push-args...]
# Or alias: alias gpp="$HOME/.local/bin/git-push-guard.sh"

set -euo pipefail

cd "$(git rev-parse --show-toplevel)" 2>/dev/null || {
  echo "✗ not inside a git repo"
  exit 1
}

REMOTE_URL=$(git remote get-url --push origin 2>/dev/null || true)
if [ -z "$REMOTE_URL" ]; then
  echo "✗ no origin remote"
  exit 1
fi

# Extract owner from https://github.com/OWNER/REPO.git or git@github.com:OWNER/REPO.git
EXPECTED=$(printf '%s' "$REMOTE_URL" | sed -E 's|^.*[/:]([^/]+)/[^/]+(\.git)?$|\1|')
if [ -z "$EXPECTED" ]; then
  echo "✗ could not parse owner from $REMOTE_URL"
  exit 1
fi

# Find the gh-active account name. Output of `gh auth status` lists each
# account; the one with "Active account: true" is current.
ACTIVE=$(gh auth status 2>&1 | awk '
  /Logged in to github.com account/ {
    sub(/^.*account /, ""); sub(/ \(.*$/, "")
    pending=$0
  }
  /Active account: true/ { print pending; exit }
')

if [ -z "$ACTIVE" ]; then
  echo "✗ could not determine active gh account (gh auth status returned nothing parseable)"
  exit 1
fi

if [ "$ACTIVE" != "$EXPECTED" ]; then
  echo "✗ refusing to push: active gh account is '$ACTIVE', but origin owner is '$EXPECTED'"
  echo "  fix: gh auth switch --user $EXPECTED"
  exit 1
fi

echo "✓ gh account $ACTIVE matches origin owner $EXPECTED"
exec git push "$@"
