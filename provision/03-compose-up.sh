#!/bin/bash
# 03-compose-up.sh — Lance la stack docker-compose (GLPI+MariaDB+phpMyAdmin)
set -euo pipefail

cd /vagrant

# Si .env absent, on copie le modèle
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "[03-compose] .env créé à partir de .env.example"
fi

# Préparer les dossiers persistants
mkdir -p data/mysql_data data/glpi_data/files data/glpi_data/plugins

echo "=== [03-compose] docker compose up -d ==="
docker compose pull -q
docker compose up -d

echo "[03-compose] Attente démarrage GLPI (90s max)..."
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ || echo 000)
  if [[ "$code" =~ ^(200|302|301)$ ]]; then
    echo "[03-compose] GLPI répond (HTTP ${code}) après ${i}x3s"
    break
  fi
  sleep 3
done

docker compose ps
echo "[03-compose] OK"
