#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
require_command docker
require_command curl

printf 'Traffic Filter Lab preflight\n'
printf '  allowed CIDR: %s\n' "${ALLOWED_CIDR}"
printf '  published port: %s\n' "${WEB_PORT}"

docker version >/dev/null
docker compose version >/dev/null
docker compose --env-file "${ROOT_DIR}/.env" -f "${ROOT_DIR}/compose.yaml" config --quiet

if [[ "$(uname -s)" != "Linux" ]]; then
  printf '\nService configuration is valid, but host firewall tests require a Linux VM.\n'
  printf 'Docker Desktop on Windows does not expose the same host Netfilter path.\n'
  exit 0
fi

require_command iptables
require_command iptables-save
require_command ip
require_command ufw

if ! iptables -S DOCKER-USER >/dev/null 2>&1; then
  printf 'DOCKER-USER chain is missing. Start Docker Engine and retry.\n' >&2
  exit 1
fi

if [[ -z "${EXTERNAL_INTERFACE}" ]]; then
  EXTERNAL_INTERFACE="$(ip route show default | awk 'NR == 1 { print $5 }')"
fi

if [[ -z "${EXTERNAL_INTERFACE}" ]] || ! ip link show "${EXTERNAL_INTERFACE}" >/dev/null 2>&1; then
  printf 'EXTERNAL_INTERFACE is missing or invalid: %s\n' "${EXTERNAL_INTERFACE:-<empty>}" >&2
  exit 1
fi

printf '  Docker Engine: ready\n'
printf '  UFW: %s\n' "$(ufw status | head -n 1)"
printf '  external interface: %s\n' "${EXTERNAL_INTERFACE}"
printf '  DOCKER-USER: ready\n'
printf 'Preflight passed.\n'
