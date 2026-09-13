#!/usr/bin/env bash
#
# Start sleeper-kdb in the background and open it in your browser.
#
#   macOS:  double-click this file in Finder
#   macOS/Linux: ./start.command
#
# Stop it again with ./stop.command

set -euo pipefail
cd "$(dirname "$0")"

PID_FILE="data/server.pid"
LOG_FILE="data/server.log"
STAMP_FILE="data/server.started"

say() { printf '%s\n' "$*"; }
fail() { printf '\n%s\n\n' "$*" >&2; exit 1; }

# --- find q -----------------------------------------------------------------
# Double-clicking in Finder does not give us the PATH from your shell profile,
# so look in the usual places as well.
find_q() {
  if command -v q >/dev/null 2>&1; then command -v q; return; fi
  for candidate in \
    "${QHOME:-}/m64/q" "${QHOME:-}/l64/q" \
    "$HOME/.kx/bin/q" \
    "$HOME/q/m64/q" "$HOME/q/l64/q" \
    /usr/local/bin/q /opt/homebrew/bin/q
  do
    [ -x "$candidate" ] && { printf '%s' "$candidate"; return; }
  done
}

Q=$(find_q)
if [ -z "$Q" ]; then
  fail "Could not find 'q'.

sleeper-kdb needs kdb+/q. Install it from
https://kx.com/kdb-personal-edition-download
and make sure 'q' runs from a terminal, then try again."
fi

# --- which port? ------------------------------------------------------------
# Read "port": NNNN from the config file if there is one, otherwise use 8080.
PORT=8080
if [ -f config/config.json ]; then
  FOUND=$(sed -n 's/.*"port"[[:space:]]*:[[:space:]]*\([0-9]\{1,5\}\).*/\1/p' config/config.json | head -1)
  [ -n "$FOUND" ] && PORT="$FOUND"
fi
URL="http://localhost:${PORT}"

open_browser() {
  if command -v open >/dev/null 2>&1; then
    open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$URL" >/dev/null 2>&1
  else
    say "Open $URL in your browser."
  fi
}

# --- already running? -------------------------------------------------------
# Either one we started, or one somebody started by hand in a terminal.
running_pid() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    cat "$PID_FILE"
    return
  fi
  if curl -fsS -m 2 "$URL/api/league" >/dev/null 2>&1 && command -v lsof >/dev/null 2>&1; then
    lsof -t -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -1
  fi
}

# q reads its source once, at start-up, so a running server keeps serving the
# code it was started with.  (The files under web/ are read per request, so
# those only need a browser reload.)
source_changed_since_start() {
  [ -f "$STAMP_FILE" ] || return 0
  [ -n "$(find q -type f -name '*.q' -newer "$STAMP_FILE" 2>/dev/null | head -1)" ]
}

RUNNING=$(running_pid)
if [ -n "$RUNNING" ]; then
  if source_changed_since_start; then
    say "The q code has changed since this was started, so it is being restarted."
    kill "$RUNNING" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$RUNNING" 2>/dev/null || break
      sleep 0.25
    done
    rm -f "$PID_FILE"
  else
    say "sleeper-kdb is already running on $URL"
    open_browser
    exit 0
  fi
fi
rm -f "$PID_FILE"

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  fail "Something else is already listening on port $PORT.

Either stop it, or change \"port\" in config/config.json."
fi

# --- start it ---------------------------------------------------------------
mkdir -p data
say "Starting sleeper-kdb on $URL ..."
touch "$STAMP_FILE"
nohup "$Q" q/main.q -q >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

# Wait for the server to answer before opening the browser.
for _ in $(seq 1 40); do
  if curl -fsS -m 1 "$URL/api/league" >/dev/null 2>&1; then
    say "Ready."
    open_browser
    say ""
    say "  Open:  $URL"
    say "  Log:   $LOG_FILE"
    say "  Stop:  ./stop.command"
    exit 0
  fi
  if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    rm -f "$PID_FILE"
    say ""
    say "sleeper-kdb stopped while starting up. The log says:"
    say ""
    tail -20 "$LOG_FILE" || true
    exit 1
  fi
  sleep 0.5
done

fail "sleeper-kdb did not answer on $URL within 20 seconds. See $LOG_FILE"
