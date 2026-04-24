#!/bin/bash
# 99-validate.sh — Validation post-déploiement
set -uo pipefail

OK="\033[1;32m[OK]\033[0m"
KO="\033[1;31m[KO]\033[0m"
pass=0; fail=0
check() {
  if eval "$2" &>/dev/null; then
    echo -e "$OK $1"; pass=$((pass+1))
  else
    echo -e "$KO $1"; fail=$((fail+1))
  fi
}

cd /vagrant

echo
echo "═══════════════════════════════════════════════════════════"
echo " VALIDATION GLPI DOCKER STACK — RP BTS SIO 2026"
echo "═══════════════════════════════════════════════════════════"

check "Docker Engine actif"               "systemctl is-active docker"
check "Docker Compose v2 disponible"      "docker compose version"
check "Conteneur glpi-db running"         "docker compose ps db | grep -q running"
check "Conteneur glpi-app running"        "docker compose ps glpi | grep -q running"
check "Conteneur glpi-phpmyadmin running" "docker compose ps phpmyadmin | grep -q running"
check "MariaDB répond ping interne"       "docker compose exec -T db healthcheck.sh --connect"
check "Base 'glpidb' créée"               "docker compose exec -T db mysql -uroot -p\$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2) -e 'SHOW DATABASES' | grep -q glpidb"
check "GLPI HTTP 200/302 sur /"           "code=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost/); [ \"\$code\" = \"200\" ] || [ \"\$code\" = \"302\" ]"
check "Page contient 'GLPI'"              "curl -sL http://localhost/ | grep -qi glpi"
check "phpMyAdmin HTTP 200 sur :8081"     "[ \$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/) = '200' ]"
check "Volume mysql_data persistant"      "[ -d data/mysql_data ] && [ \"\$(ls -A data/mysql_data 2>/dev/null)\" ]"

echo
echo " Résumé : ${pass} OK · ${fail} KO"
echo "═══════════════════════════════════════════════════════════"
echo
echo " 🌐 GLPI       : http://localhost:8080  (login: glpi / glpi)"
echo " 🛠 phpMyAdmin : http://localhost:8081"
echo
[ $fail -eq 0 ]
