#!/bin/sh
set -eu

uvicorn app.main:app --host 0.0.0.0 --port 8000 &
api_pid=$!

python -m http.server 8080 --directory /workspace/web-build &
web_pid=$!

trap 'kill "$api_pid" "$web_pid" 2>/dev/null || true' INT TERM EXIT
wait "$api_pid" "$web_pid"
