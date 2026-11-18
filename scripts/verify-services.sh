#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

load_env
require_command docker
require_command curl

cd "${ROOT_DIR}"

docker compose --env-file .env config --quiet
docker compose --env-file .env ps

curl --fail --silent --show-error "http://127.0.0.1:${WEB_PORT}/health" >/dev/null
curl --fail --silent --show-error "http://127.0.0.1:${WEB_PORT}/api/health" | grep -q '"status":"ok"'

DATABASE_ID="$(docker compose --env-file .env ps -q database)"
DATABASE_BINDING="$(docker inspect \
  --format '{{with index .NetworkSettings.Ports "5432/tcp"}}{{json .}}{{end}}' \
  "${DATABASE_ID}")"

if [[ -n "${DATABASE_BINDING}" ]]; then
  printf 'Database port is unexpectedly published.\n' >&2
  exit 1
fi

docker compose --env-file .env exec -T database \
  psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -Atc \
  "SELECT status FROM lab_status WHERE component='database';" | grep -qx ready

printf 'Service checks passed.\n'
printf '  edge health: ok\n'
printf '  internal app health through proxy: ok\n'
printf '  database query: ok\n'
printf '  database host port: not published\n'
