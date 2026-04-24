#!/bin/bash
# update_glpi.sh — Met à jour l'image GLPI vers la dernière version
# Effectue automatiquement une sauvegarde avant
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶ Sauvegarde préventive..."
bash scripts/backup.sh

echo "▶ Pull des nouvelles images"
docker compose pull

echo "▶ Recreate des conteneurs"
docker compose up -d

echo "▶ Application des migrations GLPI (si nécessaire)"
sleep 10
docker compose exec -T glpi \
  php /var/www/html/glpi/bin/console db:update --no-interaction --allow-unstable || true

echo "✅ Mise à jour terminée. Versions actuelles :"
docker compose images
