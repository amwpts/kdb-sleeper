#!/usr/bin/env bash
#
# Stop the background sleeper-kdb started by start.command.
#
#   macOS:  double-click this file in Finder
#   macOS/Linux: ./stop.command

set -euo pipefail
cd "$(dirname "$0")"

PID_FILE="data/server.pid"

if [ ! -f "$PID_FILE" ]; then
  printf '%s\n' "sleeper-kdb does not appear to be running."
  exit 0
fi

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  printf '%s\n' "Stopped sleeper-kdb (pid $PID)."
else
  printf '%s\n' "sleeper-kdb was not running."
fi
rm -f "$PID_FILE" data/server.started
