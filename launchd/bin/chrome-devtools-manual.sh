#!/usr/bin/env bash
# chrome-devtools-manual.sh
# Launcher for the chrome-devtools-manual MCP entry.
# Ensures a Chrome instance is listening on 127.0.0.1:9223 with a dedicated
# user-data-dir, then exec's chrome-devtools-mcp@latest attached to it.
#
# The MCP entry's args are forwarded as $@ so registration stays in `claude mcp`.

set -euo pipefail

PORT=9223
PROFILE_DIR="${HOME}/.local/share/chrome-devtools-manual-profile"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LOG_FILE="/tmp/chrome-devtools-manual.log"

mkdir -p "${PROFILE_DIR}"

is_up() {
  curl -sS --max-time 1 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1
}

port_bound() {
  lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN -t 2>/dev/null | head -n1
}

kill_port() {
  local pids
  pids=$(lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN -t 2>/dev/null || true)
  [ -z "${pids}" ] && return 0
  echo "[$(date '+%F %T')] killing stale process(es) on :${PORT}: ${pids}" >>"${LOG_FILE}"
  # SIGTERM first, then SIGKILL anything still hanging on.
  kill ${pids} 2>/dev/null || true
  for _ in $(seq 1 6); do
    sleep 0.25
    [ -z "$(port_bound)" ] && return 0
  done
  pids=$(port_bound || true)
  [ -n "${pids}" ] && kill -9 ${pids} 2>/dev/null || true
  sleep 0.25
}

if ! is_up; then
  if [ -n "$(port_bound)" ]; then
    echo "[$(date '+%F %T')] :${PORT} bound but unresponsive, killing" >>"${LOG_FILE}"
    kill_port
  fi
  echo "[$(date '+%F %T')] launching Chrome on :${PORT}" >>"${LOG_FILE}"
  # Background, detached, suppress output. Chrome stays up across MCP restarts.
  nohup "${CHROME_BIN}" \
    --remote-debugging-port="${PORT}" \
    --user-data-dir="${PROFILE_DIR}" \
    --no-first-run \
    --no-default-browser-check \
    >>"${LOG_FILE}" 2>&1 &
  disown || true

  # Wait up to 10s for the debugger to come up.
  for _ in $(seq 1 20); do
    if is_up; then
      break
    fi
    sleep 0.5
  done

  if ! is_up; then
    echo "[$(date '+%F %T')] Chrome did not come up on :${PORT}" >>"${LOG_FILE}"
    exit 1
  fi
fi

exec npx -y chrome-devtools-mcp@latest "$@"
