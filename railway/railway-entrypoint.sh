#!/usr/bin/env bash
# railway-entrypoint.sh — patche Apache pour le port Railway puis délègue à l'init GLPI upstream
set -euo pipefail

PORT="${PORT:-80}"

if [ "$PORT" != "80" ]; then
  echo "[railway] Patch port Apache : 80 → ${PORT}"
  sed -ri "s/^Listen 80$/Listen ${PORT}/" /etc/apache2/ports.conf
  # glpi-start.sh réécrit 000-default.conf avec *:80 en dur → patcher le script lui-même
  sed -ri "s|VirtualHost \\*:80|VirtualHost *:${PORT}|g" /opt/glpi-start.sh
fi

# Silence wget (sinon il sature les logs Railway et masque les erreurs Apache)
sed -ri 's|wget -P|wget -nv -P|g' /opt/glpi-start.sh
# Marker visible après la fin du script (jamais atteint car apache2ctl bloque, mais signale crash)
echo 'echo "[railway] apache2ctl a quitté inopinément"' >> /opt/glpi-start.sh

# Background : 8s après le boot, lister les ports en écoute
( sleep 8 && echo "[railway] === Ports en écoute ===" && (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "pas de ss/netstat") ) &

# Mappage vars Railway → vars attendues par glpi-start.sh / GLPI
export DB_HOST="${MYSQLHOST:-${DB_HOST:-mariadb}}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_USER="${MYSQLUSER:-${DB_USER:-glpi}}"
export DB_PASSWORD="${MYSQLPASSWORD:-${DB_PASSWORD:-glpi}}"
export DB_NAME="${MYSQLDATABASE:-${DB_NAME:-glpi}}"
export TIMEZONE="${TIMEZONE:-Europe/Paris}"

echo "[railway] DB_HOST=${DB_HOST}  DB_NAME=${DB_NAME}  PORT=${PORT}"
echo "[railway] === DIAGNOSTIC ==="
echo "[railway] PORT env brut = '${PORT}'"
echo "[railway] HOSTNAME = $(hostname -i 2>/dev/null || echo n/a)"
grep -E "^Listen " /etc/apache2/ports.conf || true
grep -E "VirtualHost" /etc/apache2/sites-available/000-default.conf 2>/dev/null || echo "(000-default.conf pas encore écrit)"
echo "[railway] =================="
echo "[railway] Délégation à /opt/glpi-start.sh"

exec /opt/glpi-start.sh "$@"
