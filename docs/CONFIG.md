# ⚙ CONFIG.md — Variables, ports, volumes

## Variables d'environnement (`.env`)

| Variable               | Valeur exemple             | Rôle                                       |
|------------------------|----------------------------|--------------------------------------------|
| `MYSQL_ROOT_PASSWORD`  | `ChangeMe_Root_2026`       | Mot de passe root MariaDB                  |
| `MYSQL_DATABASE`       | `glpidb`                   | Nom de la base GLPI                        |
| `MYSQL_USER`           | `glpiuser`                 | Utilisateur applicatif GLPI                |
| `MYSQL_PASSWORD`       | `ChangeMe_Glpi_2026`       | Mot de passe utilisateur applicatif        |
| `GLPI_VERSION`         | `10.0.18`                  | Version GLPI cible (image diouxx)          |
| `TZ`                   | `Europe/Paris`             | Fuseau horaire conteneurs                  |
| `DOMAIN_NAME`          | `saiddev.fr`               | (PROD) domaine racine pour Traefik         |
| `ACME_EMAIL`           | `said@saiddev.fr`          | (PROD) email Let's Encrypt                 |

➡️ **Sécurité** : `.env` est dans `.gitignore`. Ne jamais le pousser.

---

## Ports

| Port hôte | Port conteneur | Service     | Mode      |
|-----------|----------------|-------------|-----------|
| 8080      | 80             | GLPI        | DEV       |
| 8081      | 80             | phpMyAdmin  | DEV       |
| 80        | 80             | Traefik     | PROD      |
| 443       | 443            | Traefik     | PROD      |

---

## Volumes

| Volume hôte                  | Conteneur                              | Contenu                          |
|------------------------------|----------------------------------------|----------------------------------|
| `./data/mysql_data`          | `/var/lib/mysql`                       | Base MariaDB                     |
| `./data/glpi_data/files`     | `/var/www/html/glpi/files`             | Documents, dumps, sessions       |
| `./data/glpi_data/plugins`   | `/var/www/html/glpi/plugins`           | Plugins installés                |
| `./configs/php/*.ini`        | `/usr/local/etc/php/conf.d/`           | Surcharges PHP                   |
| `./configs/mariadb/*.cnf`    | `/etc/mysql/conf.d/`                   | Tuning MariaDB                   |
| `./data/traefik/letsencrypt` | `/letsencrypt`                         | (PROD) Certificats ACME          |

---

## Réseaux Docker

| Réseau     | Driver | Interne ? | Usage                                       |
|------------|--------|-----------|---------------------------------------------|
| `glpi-net` | bridge | oui       | GLPI ↔ MariaDB ↔ phpMyAdmin                 |
| `web`      | bridge | externe   | (PROD) Traefik ↔ services exposés           |

Création prod : `docker network create web`.

---

## Healthchecks

```yaml
db:
  healthcheck:
    test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
    interval: 10s
    timeout: 5s
    retries: 10
```

Le service `glpi` attend `db: service_healthy` avant de démarrer.

---

## Surcharges PHP appliquées (`configs/php/glpi-custom.ini`)

```ini
memory_limit         = 256M
upload_max_filesize  = 32M
post_max_size        = 32M
max_execution_time   = 300
date.timezone        = Europe/Paris
session.cookie_httponly = On
```

## Tuning MariaDB (`configs/mariadb/glpi-tuning.cnf`)

```ini
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci
innodb_buffer_pool_size = 256M
max_allowed_packet      = 64M
```
