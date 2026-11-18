#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
require_command docker

cd "${ROOT_DIR}"

docker compose --env-file .env --profile tools run --rm dmz-test \
  sh -ec 'wget -q -O - http://edge:8080/health | grep -q "edge: ok"'

if docker compose --env-file .env --profile tools run --rm dmz-test \
  sh -ec 'nc -z -w 2 database 5432' >/dev/null 2>&1; then
  printf 'Segmentation failure: DMZ can reach the database.\n' >&2
  exit 1
fi

docker compose --env-file .env --profile tools run --rm data-test \
  pg_isready -h database -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null

printf 'Network segmentation checks passed.\n'
printf '  DMZ -> edge: allowed\n'
printf '  DMZ -> database: blocked\n'
printf '  data network -> database: allowed\n'
