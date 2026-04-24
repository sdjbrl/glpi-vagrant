#!/bin/bash
# 01-base.sh — Préparation Debian 12
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== [01-base] Mise à jour & paquets de base ==="
apt-get update -qq
apt-get -y -qq upgrade >/dev/null
apt-get -y -qq install \
  ca-certificates curl wget gnupg lsb-release \
  vim htop tree net-tools jq sudo \
  >/dev/null

timedatectl set-timezone Europe/Paris || true

cat <<'EOF' > /etc/motd

╔══════════════════════════════════════════════════════════════════╗
║  glpi-srv — Stack Docker GLPI 10 + MariaDB + phpMyAdmin          ║
║  Saïd AHMED MOUSSA (sdjbrl) — RP BTS SIO 2026                    ║
║  Inspiration : Mediaschool-IRIS-BTS-SISR-2025/Serveur_GLPI_Louka ║
║  Cible prod  : glpi.saiddev.fr                                   ║
║                                                                  ║
║  🌐 GLPI       : http://localhost:8080                           ║
║  🛠 phpMyAdmin : http://localhost:8081                           ║
║  📁 Projet     : /vagrant                                        ║
║                                                                  ║
║  Commandes utiles :                                              ║
║    cd /vagrant && docker compose ps                              ║
║    docker compose logs -f glpi                                   ║
║    bash scripts/backup.sh                                        ║
╚══════════════════════════════════════════════════════════════════╝

EOF

echo "[01-base] OK"
