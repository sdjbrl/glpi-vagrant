#!/bin/bash
# restore.sh — Restaure une sauvegarde donnée
# Usage : ./scripts/restore.sh ./backups/20260424_120000
set -euo pipefail

cd "$(dirname "$0")/.."
source .env

SRC="${1:-}"
if [[ -z "${SRC}" || ! -d "${SRC}" ]]; then
  echo "Usage : $0 <chemin-vers-backup>"
  echo "Sauvegardes disponibles :"
  ls -1dt ./backups/*/ 2>/dev/null | head -5
  exit 1
fi

echo "⚠  Restauration de ${SRC} → ÉCRASE les données actuelles"
read -p "Confirmer (y/N) ? " ans
[[ "${ans,,}" == "y" ]] || { echo "Annulé."; exit 0; }

echo "▶ Restauration BDD"
gunzip -c "${SRC}/glpidb.sql.gz" \
  | docker compose exec -T db mariadb -uroot -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}"

echo "▶ Restauration fichiers GLPI"
docker compose stop glpi
rm -rf ./data/glpi_data
tar xzf "${SRC}/glpi_files.tar.gz" -C ./data
docker compose start glpi

echo "✅ Restauration terminée."
