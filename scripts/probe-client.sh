#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Usage: %s HOST [PORT]\n' "$0" >&2
  exit 2
fi

HOST="$1"
PORT="${2:-8080}"

printf 'Probing http://%s:%s/health\n' "${HOST}" "${PORT}"
curl --verbose --connect-timeout 4 --max-time 8 "http://${HOST}:${PORT}/health"
