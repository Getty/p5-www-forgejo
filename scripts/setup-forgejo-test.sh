#!/bin/bash
# Start the throwaway Forgejo from docker-compose.yaml, create an admin user
# and print an access token for the live tests (t/9*-live-*.t). Progress goes
# to stderr, the export lines to stdout:
#   eval "$(scripts/setup-forgejo-test.sh)"
# The Docker healthcheck is not relied on; the script polls /api/v1/version.
set -euo pipefail

cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-wwwforgejo-live}"

TEST_FORGEJO_URL="${TEST_FORGEJO_URL:-http://localhost:13080}"
TOKEN_NAME="${TOKEN_NAME:-live-tests-$(date +%s)}"
ADMIN_USER="${ADMIN_USER:-forgejo_admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@localhost}"
ADMIN_PASS="${ADMIN_PASS:-Admin123!}"

echo "==> Starting Forgejo..." >&2
docker compose up -d forgejo >&2
for i in $(seq 1 120); do
    curl -sf "${TEST_FORGEJO_URL}/api/v1/version" > /dev/null && break
    [ "$i" = 120 ] && { echo "Forgejo did not come up" >&2; exit 1; }
    sleep 1
done

forgejo_cli() {
    docker compose exec -T -u git forgejo forgejo "$@"
}

echo "==> Creating admin user ${ADMIN_USER} (if missing)..." >&2
if ! forgejo_cli admin user list | awk '{print $2}' | grep -qx "$ADMIN_USER"; then
    forgejo_cli admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASS" \
        --email "$ADMIN_EMAIL" \
        --must-change-password=false \
        --admin >&2
fi

echo "==> Creating access token..." >&2
TOKEN=$(forgejo_cli admin user generate-access-token \
    --username "$ADMIN_USER" \
    --token-name "$TOKEN_NAME" \
    --scopes all \
    --raw)

cat >&2 <<EOF

Forgejo test instance ready: ${TEST_FORGEJO_URL} (admin ${ADMIN_USER} / ${ADMIN_PASS})

EOF
echo "export TEST_FORGEJO_URL='${TEST_FORGEJO_URL}'"
echo "export TEST_FORGEJO_TOKEN='${TOKEN}'"
