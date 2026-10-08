#!/bin/bash
cd "$(dirname "$0")"
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 20+ is required. Install it, then run this file again."
  exit 1
fi
export NODE_ENV=development
export CINESET_SECRET="${CINESET_SECRET:-dev-secret-change-me}"
node server.js &
PID=$!
sleep 1
open "http://localhost:${PORT:-3000}"
wait $PID
