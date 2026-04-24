#!/usr/bin/env bash
# railway-entrypoint.sh — déploie GLPI sur Railway de manière fiable
set -uo pipefail

PORT="${PORT:-80}"
GLPI_VERSION="${GLPI_VERSION:-10.0.18}"
TIMEZONE="${TIMEZONE:-Europe/Paris}"
FOLDER_WEB="/var/www/html"
FOLDER_GLPI="${FOLDER_WEB}/glpi"

echo "[railway] === BOOT GLPI ==="
echo "[railway] PORT=${PORT}  GLPI_VERSION=${GLPI_VERSION}  TZ=${TIMEZONE}"

# 1) Timezone PHP
if [ -d /etc/php/8.3/apache2/conf.d ]; then
  echo "date.timezone = \"${TIMEZONE}\"" > /etc/php/8.3/apache2/conf.d/timezone.ini
  echo "date.timezone = \"${TIMEZONE}\"" > /etc/php/8.3/cli/conf.d/timezone.ini
fi

# 2) Mappage variables Railway -> GLPI (juste pour les logs, pas utilisé par l'install web)
export DB_HOST="${MYSQLHOST:-mariadb}"
export DB_PORT="${MYSQLPORT:-3306}"
export DB_USER="${MYSQLUSER:-glpi}"
export DB_PASSWORD="${MYSQLPASSWORD:-glpi}"
export DB_NAME="${MYSQLDATABASE:-glpi}"
echo "[railway] DB cible : ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# 3) Téléchargement GLPI si absent
if [ ! -d "${FOLDER_GLPI}/bin" ]; then
  echo "[railway] Téléchargement GLPI ${GLPI_VERSION}..."
  TARBALL="glpi-${GLPI_VERSION}.tgz"
  URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/${TARBALL}"
  wget -nv -P "${FOLDER_WEB}" "${URL}"
  tar -xzf "${FOLDER_WEB}/${TARBALL}" -C "${FOLDER_WEB}"
  rm -f "${FOLDER_WEB}/${TARBALL}"
  chown -R www-data:www-data "${FOLDER_GLPI}"
  echo "[railway] GLPI extrait dans ${FOLDER_GLPI}"
else
  echo "[railway] GLPI déjà présent dans ${FOLDER_GLPI}"
fi

# 4) Détection version pour DocumentRoot (GLPI >=10.0.7 utilise /public)
LOCAL_VER=$(ls "${FOLDER_GLPI}/version" 2>/dev/null | head -1 || echo "${GLPI_VERSION}")
LOCAL_NUM=${LOCAL_VER//./}
LOCAL_MAJOR=$(echo "$LOCAL_VER" | cut -d. -f1)

if [ "$LOCAL_MAJOR" -ge 10 ] && [ "$LOCAL_NUM" -ge 1007 ]; then
  DOCROOT="${FOLDER_GLPI}/public"
  VHOST_EXTRA=$'\t\tRequire all granted\n\t\tRewriteEngine On\n\t\tRewriteCond %{REQUEST_FILENAME} !-f\n\t\tRewriteRule ^(.*)$ index.php [QSA,L]'
else
  DOCROOT="${FOLDER_GLPI}"
  VHOST_EXTRA=$'\t\tAllowOverride All\n\t\tRequire all granted'
fi
echo "[railway] DocumentRoot=${DOCROOT}  Version=${LOCAL_VER}"

# 5) Conf Apache : Listen + VirtualHost sur $PORT
sed -ri "s/^Listen 80$/Listen ${PORT}/" /etc/apache2/ports.conf
cat > /etc/apache2/sites-available/000-default.conf <<EOF
<VirtualHost *:${PORT}>
    DocumentRoot ${DOCROOT}
    <Directory ${DOCROOT}>
${VHOST_EXTRA}
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error-glpi.log
    CustomLog \${APACHE_LOG_DIR}/access-glpi.log combined
</VirtualHost>
EOF

a2enmod rewrite >/dev/null 2>&1
a2ensite 000-default >/dev/null 2>&1

# 6) Cron GLPI
echo "*/2 * * * * www-data /usr/bin/php ${FOLDER_GLPI}/front/cron.php &>/dev/null" > /etc/cron.d/glpi
service cron start >/dev/null 2>&1 || true

# 7) Test config + lancement Apache au premier plan (PID 1)
echo "[railway] Test config Apache :"
apache2ctl configtest 2>&1 || { echo "[railway] !! configtest FAILED"; exit 1; }

# Source les envvars Apache (APACHE_RUN_USER, APACHE_LOG_DIR, etc.)
if [ -f /etc/apache2/envvars ]; then
  set -a
  . /etc/apache2/envvars
  set +a
fi

# Crée les répertoires runtime si manquants
mkdir -p "${APACHE_RUN_DIR:-/var/run/apache2}" "${APACHE_LOG_DIR:-/var/log/apache2}" "${APACHE_LOCK_DIR:-/var/lock/apache2}"

echo "[railway] === Apache démarre sur :${PORT} → ${DOCROOT} ==="
echo "[railway] APACHE_RUN_DIR=${APACHE_RUN_DIR}  APACHE_LOG_DIR=${APACHE_LOG_DIR}"

# Lance apache2 directement (pas le wrapper apache2ctl) pour rester PID 1 et logger sur stdout
exec /usr/sbin/apache2 -D FOREGROUND -e info
