#!/bin/bash
set -e

# Setup-Script für Forgejo Test-Environment
# Erstellt Admin-User und Token für Live-Tests

FORGEJO_URL="${FORGEJO_URL:-http://localhost:30080}"
TOKEN_NAME="${TOKEN_NAME:-test-token}"
ADMIN_USER="${ADMIN_USER:-forgejo_admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@localhost}"
ADMIN_PASS="${ADMIN_PASS:-Admin123!}"

echo "==> Starte Forgejo und PostgreSQL..."
docker compose up -d
docker compose wait -s postgres

echo "==> Warte auf Forgejo Web-Interface..."
for i in $(seq 1 30); do
    if curl -sf "${FORGEJO_URL}/" > /dev/null 2>&1; then
        echo "   Forgejo ist bereit nach ${i}s"
        break
    fi
    sleep 1
done

# Prüfe ob bereits installiert (INSTALL_LOCK=true aus Docker Env)
curl -sf "${FORGEJO_URL}/api/v1/version" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "==> Forgejo bereits installiert, überspringe Installation"
else
    echo "==> Forgejo muss noch installiert werden (INSTALL_LOCK=false)"
    echo "   Bitte manuell installieren unter: ${FORGEJO_URL}/"
    echo "   Oder nutze: docker compose exec -u git forgejo gitea admin user create ..."
fi

# Warte bis Container bereit für CLI
sleep 5

echo "==> Erstelle Admin-User wenn nicht vorhanden..."
docker compose exec -u git forgejo gitea admin user list 2>/dev/null | grep -q "$ADMIN_USER" || \
    docker compose exec -u git forgejo gitea admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASS" \
        --email "$ADMIN_EMAIL" \
        --admin 2>/dev/null || true

echo "==> Erstelle Access Token..."
TOKEN=$(docker compose exec -u git forgejo gitea admin user generate-access-token \
    --username "$ADMIN_USER" \
    --token-name "$TOKEN_NAME" \
    --scopes "sudo" \
    --raw 2>/dev/null)

if [ -n "$TOKEN" ]; then
    echo ""
    echo "=========================================="
    echo "  Forgejo Test Environment Ready!"
    echo "=========================================="
    echo ""
    echo "  URL:        ${FORGEJO_URL}"
    echo "  Username:   ${ADMIN_USER}"
    echo "  Password:   ${ADMIN_PASS}"
    echo "  Token:      ${TOKEN}"
    echo ""
    echo "  Export:"
    echo "    export FORGEJO_URL='${FORGEJO_URL}'"
    echo "    export FORGEJO_TOKEN='${TOKEN}'"
    echo ""
else
    echo "==> Token-Erstellung fehlgeschlagen. Bitte manuell erstellen."
fi