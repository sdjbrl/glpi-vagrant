#!/bin/bash
# 02-docker.sh — Docker Engine + Compose v2 (repo officiel)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== [02-docker] Installation Docker Engine ==="

install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi

CODENAME=$(. /etc/os-release && echo "${VERSION_CODENAME}")
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get -y -qq install \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin \
  >/dev/null

systemctl enable --now docker
usermod -aG docker vagrant || true

echo "[02-docker] $(docker --version)"
echo "[02-docker] $(docker compose version)"
echo "[02-docker] OK"
