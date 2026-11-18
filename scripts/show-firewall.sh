#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
require_command iptables
require_command ufw

printf '%s\n' '--- UFW ---'
ufw status verbose

printf '%s\n' '--- DOCKER-USER ---'
iptables -L DOCKER-USER -n -v --line-numbers

printf '%s\n' '--- TFL-FILTER ---'
if iptables -S TFL-FILTER >/dev/null 2>&1; then
  iptables -L TFL-FILTER -n -v --line-numbers
else
  printf 'TFL-FILTER is not installed.\n'
fi
