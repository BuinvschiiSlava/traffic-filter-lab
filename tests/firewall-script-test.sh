#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
MOCK_BIN="${TEST_DIR}/bin"
MOCK_LOG="${TEST_DIR}/commands.log"
MOCK_STATE="${TEST_DIR}/mock-state"
LAB_STATE="${TEST_DIR}/lab-state"

cleanup() {
  if [[ "${EUID}" -eq 0 ]]; then
    rm -rf "${TEST_DIR}"
  else
    sudo rm -rf "${TEST_DIR}"
  fi
}
trap cleanup EXIT

mkdir -p "${MOCK_BIN}" "${MOCK_STATE}"
touch "${MOCK_LOG}"

cat > "${MOCK_BIN}/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker' >> "${MOCK_LOG}"
printf ' %q' "$@" >> "${MOCK_LOG}"
printf '\n' >> "${MOCK_LOG}"
EOF

cat > "${MOCK_BIN}/ip" <<'EOF'
#!/usr/bin/env bash
printf 'ip' >> "${MOCK_LOG}"
printf ' %q' "$@" >> "${MOCK_LOG}"
printf '\n' >> "${MOCK_LOG}"

case "${1:-} ${2:-}" in
  'link show') [[ "${3:-}" == eth0 ]] ;;
  'route show') printf 'default via 192.0.2.1 dev eth0\n' ;;
  *) exit 1 ;;
esac
EOF

cat > "${MOCK_BIN}/iptables-save" <<'EOF'
#!/usr/bin/env bash
printf '*filter\nCOMMIT\n'
EOF

cat > "${MOCK_BIN}/ufw" <<'EOF'
#!/usr/bin/env bash
printf 'ufw' >> "${MOCK_LOG}"
printf ' %q' "$@" >> "${MOCK_LOG}"
printf '\n' >> "${MOCK_LOG}"
if [[ "${1:-}" == status ]]; then
  printf 'Status: active\n'
fi
EOF

cat > "${MOCK_BIN}/iptables" <<'EOF'
#!/usr/bin/env bash
printf 'iptables' >> "${MOCK_LOG}"
printf ' %q' "$@" >> "${MOCK_LOG}"
printf '\n' >> "${MOCK_LOG}"

case "$*" in
  '-S DOCKER-USER') exit 0 ;;
  '-S TFL-FILTER') [[ -f "${MOCK_STATE}/chain" ]] ;;
  '-N TFL-FILTER') touch "${MOCK_STATE}/chain" ;;
  '-C DOCKER-USER -j TFL-FILTER') [[ -f "${MOCK_STATE}/jump" ]] ;;
  '-I DOCKER-USER 1 -j TFL-FILTER') touch "${MOCK_STATE}/jump" ;;
  '-D DOCKER-USER -j TFL-FILTER') rm -f "${MOCK_STATE}/jump" ;;
  '-X TFL-FILTER') rm -f "${MOCK_STATE}/chain" ;;
esac
EOF

chmod +x "${MOCK_BIN}"/*

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    env "$@"
  else
    sudo env "$@"
  fi
}

run_as_root \
  PATH="${MOCK_BIN}:${PATH}" \
  MOCK_LOG="${MOCK_LOG}" \
  MOCK_STATE="${MOCK_STATE}" \
  STATE_DIR="${LAB_STATE}" \
  bash "${ROOT_DIR}/scripts/apply-firewall.sh" >/dev/null

grep -Fq 'iptables -A TFL-FILTER -i eth0 -p tcp -s 192.168.56.0/24' "${MOCK_LOG}"
grep -Fq 'iptables -A TFL-FILTER -i eth0 -p tcp -m conntrack --ctorigdstport 8080 -j DROP' "${MOCK_LOG}"
grep -Fq 'iptables -I DOCKER-USER 1 -j TFL-FILTER' "${MOCK_LOG}"
[[ -f "${MOCK_STATE}/jump" ]]

run_as_root \
  PATH="${MOCK_BIN}:${PATH}" \
  MOCK_LOG="${MOCK_LOG}" \
  MOCK_STATE="${MOCK_STATE}" \
  STATE_DIR="${LAB_STATE}" \
  bash "${ROOT_DIR}/scripts/rollback-firewall.sh" >/dev/null

grep -Fq 'iptables -D DOCKER-USER -j TFL-FILTER' "${MOCK_LOG}"
grep -Fq 'iptables -X TFL-FILTER' "${MOCK_LOG}"
[[ ! -e "${MOCK_STATE}/jump" ]]

printf 'Firewall apply and rollback checks passed.\n'
