#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
require_command iptables
require_command ufw

if [[ -f "${STATE_DIR}/firewall.env" ]]; then
  # shellcheck disable=SC1091
  source "${STATE_DIR}/firewall.env"
fi

while iptables -C DOCKER-USER -j TFL-FILTER >/dev/null 2>&1; do
  iptables -D DOCKER-USER -j TFL-FILTER
done

if iptables -S TFL-FILTER >/dev/null 2>&1; then
  iptables -F TFL-FILTER
  iptables -X TFL-FILTER
fi

ufw delete allow from "${ALLOWED_CIDR}" to any port "${WEB_PORT}" proto tcp >/dev/null 2>&1 || true

if [[ "${UFW_WAS_ACTIVE:-yes}" == no ]]; then
  if [[ "${RESTORE_UFW_STATE:-no}" == yes ]]; then
    ufw --force disable >/dev/null
  else
    printf 'UFW was inactive before the lab. It remains enabled for safety.\n'
    printf 'Set RESTORE_UFW_STATE=yes if this disposable VM must return to the inactive state.\n'
  fi
fi

printf 'Traffic Filter Lab rules were removed.\n'
