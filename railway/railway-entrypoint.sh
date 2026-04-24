#!/usr/bin/env bash
# railway-entrypoint.sh — patche Apache pour le port Railway puis délègue à l'init GLPI upstream
set -euo pipefail

PORT="${PORT:-80}"

if [ "$PORT" != "80" ]; then
  echo "[railway] Reconfiguration Apache : port 80 → ${PORT}"
  sed -ri "s/^Listen 80$/Listen ${PORT}/" /etc/apache2/ports.conf
  sed -ri "s|<VirtualHost \\*:80>|<VirtualHost *:${PORT}>|" /etc/apache2/sites-enabled/000-default.conf || true
fi

# Mappage vars Railway → vars attendues par le script glpi-start.sh de diouxx
export DB_HOST="${MYSQLHOST:-${DB_HOST:-mariadb}}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_USER="${MYSQLUSER:-${DB_USER:-glpi}}"
export DB_PASSWORD="${MYSQLPASSWORD:-${DB_PASSWORD:-glpi}}"
export DB_NAME="${MYSQLDATABASE:-${DB_NAME:-glpi}}"
export TIMEZONE="${TIMEZONE:-Europe/Paris}"

echo "[railway] DB_HOST=${DB_HOST}  DB_NAME=${DB_NAME}  PORT=${PORT}"
echo "[railway] Délégation à /opt/glpi-start.sh (init GLPI + Apache)"

exec /opt/glpi-start.sh "$@"
