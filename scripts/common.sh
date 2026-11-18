#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STATE_DIR="${STATE_DIR:-${ROOT_DIR}/.state}"

load_env() {
  if [[ ! -f "${ROOT_DIR}/.env" ]]; then
    printf 'Missing %s/.env. Copy .env.example to .env first.\n' "${ROOT_DIR}" >&2
    exit 1
  fi

  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a

  : "${WEB_PORT:=8080}"
  : "${ALLOWED_CIDR:=192.168.56.0/24}"
  : "${EXTERNAL_INTERFACE:=}"
  : "${POSTGRES_DB:=traffic_lab}"
  : "${POSTGRES_USER:=traffic_lab}"

  if [[ ! "${WEB_PORT}" =~ ^[0-9]+$ ]] || (( WEB_PORT < 1 || WEB_PORT > 65535 )); then
    printf 'WEB_PORT must be an integer from 1 to 65535.\n' >&2
    exit 1
  fi

  if [[ ! "${ALLOWED_CIDR}" =~ ^[0-9a-fA-F:.]+/[0-9]{1,3}$ ]]; then
    printf 'ALLOWED_CIDR must use CIDR notation, for example 192.168.56.0/24.\n' >&2
    exit 1
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf 'Run this script with sudo.\n' >&2
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$1" >&2
    exit 1
  fi
}
