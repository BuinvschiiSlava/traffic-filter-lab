#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
require_command docker
require_command iptables
require_command iptables-save
require_command ufw
require_command ip

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'Host firewall configuration is supported only on Linux.\n' >&2
  exit 1
fi

docker version >/dev/null

if [[ -z "${EXTERNAL_INTERFACE}" ]]; then
  EXTERNAL_INTERFACE="$(ip route show default | awk 'NR == 1 { print $5 }')"
fi

if [[ -z "${EXTERNAL_INTERFACE}" ]] || ! ip link show "${EXTERNAL_INTERFACE}" >/dev/null 2>&1; then
  printf 'EXTERNAL_INTERFACE is missing or invalid: %s\n' "${EXTERNAL_INTERFACE:-<empty>}" >&2
  exit 1
fi

if ! iptables -S DOCKER-USER >/dev/null 2>&1; then
  printf 'DOCKER-USER chain is missing. Start Docker Engine first.\n' >&2
  exit 1
fi

mkdir -p "${STATE_DIR}"
chmod 700 "${STATE_DIR}"

if [[ ! -f "${STATE_DIR}/iptables.before.v4" ]]; then
  iptables-save > "${STATE_DIR}/iptables.before.v4"
  chmod 600 "${STATE_DIR}/iptables.before.v4"
fi

if ufw status | grep -q '^Status: active'; then
  UFW_WAS_ACTIVE=yes
else
  UFW_WAS_ACTIVE=no
fi

cat > "${STATE_DIR}/firewall.env" <<EOF
UFW_WAS_ACTIVE=${UFW_WAS_ACTIVE}
WEB_PORT=${WEB_PORT}
ALLOWED_CIDR=${ALLOWED_CIDR}
EXTERNAL_INTERFACE=${EXTERNAL_INTERFACE}
EOF
chmod 600 "${STATE_DIR}/firewall.env"

ufw allow OpenSSH >/dev/null
ufw allow from "${ALLOWED_CIDR}" to any port "${WEB_PORT}" proto tcp >/dev/null

if [[ "${UFW_WAS_ACTIVE}" == no ]]; then
  if [[ "${ENABLE_UFW:-no}" != yes ]]; then
    printf 'UFW is inactive. OpenSSH and the lab rule were prepared, but UFW was not enabled.\n' >&2
    printf 'Review "ufw status verbose", then rerun with ENABLE_UFW=yes.\n' >&2
    exit 2
  fi
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw --force enable >/dev/null
fi

iptables -N TFL-FILTER 2>/dev/null || true
iptables -F TFL-FILTER

iptables -A TFL-FILTER \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j RETURN

iptables -A TFL-FILTER \
  -i "${EXTERNAL_INTERFACE}" \
  -p tcp -s "${ALLOWED_CIDR}" \
  -m conntrack --ctorigdstport "${WEB_PORT}" \
  -j RETURN

iptables -A TFL-FILTER \
  -i "${EXTERNAL_INTERFACE}" \
  -p tcp \
  -m conntrack --ctorigdstport "${WEB_PORT}" \
  -m limit --limit 6/min --limit-burst 10 \
  -j LOG --log-prefix "TFL-DROP " --log-level 6

iptables -A TFL-FILTER \
  -i "${EXTERNAL_INTERFACE}" \
  -p tcp \
  -m conntrack --ctorigdstport "${WEB_PORT}" \
  -j DROP

iptables -A TFL-FILTER -j RETURN

if ! iptables -C DOCKER-USER -j TFL-FILTER >/dev/null 2>&1; then
  iptables -I DOCKER-USER 1 -j TFL-FILTER
fi

if [[ "${PERSIST_RULES:-no}" == yes ]]; then
  if [[ -d /etc/iptables ]]; then
    iptables-save > /etc/iptables/rules.v4
  else
    printf 'PERSIST_RULES=yes, but /etc/iptables is missing. Install iptables-persistent first.\n' >&2
    exit 3
  fi
fi

printf 'Firewall applied.\n'
printf '  allowed source: %s\n' "${ALLOWED_CIDR}"
printf '  external interface: %s\n' "${EXTERNAL_INTERFACE}"
printf '  protected published port: %s/tcp\n' "${WEB_PORT}"
printf '  Docker chain: DOCKER-USER -> TFL-FILTER\n'
printf 'Run scripts/show-firewall.sh to inspect the result.\n'
