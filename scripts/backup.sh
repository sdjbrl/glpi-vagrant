#!/bin/bash
# backup.sh — Sauvegarde complète (BDD + fichiers GLPI)
# Génère une archive horodatée dans ./backups/
set -euo pipefail

cd "$(dirname "$0")/.."
source .env

STAMP=$(date +%Y%m%d_%H%M%S)
DEST="./backups/${STAMP}"
mkdir -p "${DEST}"

echo "▶ Dump MariaDB → ${DEST}/glpidb.sql.gz"
docker compose exec -T db \
  mariadb-dump -uroot -p"${MYSQL_ROOT_PASSWORD}" --single-transaction --routines --events "${MYSQL_DATABASE}" \
  | gzip -9 > "${DEST}/glpidb.sql.gz"

echo "▶ Archive fichiers GLPI → ${DEST}/glpi_files.tar.gz"
tar czf "${DEST}/glpi_files.tar.gz" -C ./data glpi_data

echo "▶ Conservation des 7 dernières sauvegardes uniquement"
ls -1dt ./backups/*/ 2>/dev/null | tail -n +8 | xargs -r rm -rf

echo "✅ Sauvegarde terminée : ${DEST}"
du -sh "${DEST}"
