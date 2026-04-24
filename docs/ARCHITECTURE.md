# 🏛 ARCHITECTURE.md — Vue technique

## Schéma logique

### Mode DEV (Vagrant)

```
┌────────────────────── HÔTE (Windows / macOS / Linux) ─────────────────────┐
│                                                                            │
│  Navigateur ──► localhost:8080 ──┐                                         │
│  Navigateur ──► localhost:8081 ──┤                                         │
│                                  │                                         │
│  ┌──── VM Vagrant (Debian 12, 2 vCPU / 2 Go) ──────────────────────────┐  │
│  │                              │                                       │  │
│  │  Docker Engine               ▼                                       │  │
│  │  ┌──────────────┐    ┌──────────────┐    ┌────────────────┐         │  │
│  │  │  glpi-app    │◄──►│   glpi-db    │◄──►│ glpi-phpmyadmin│         │  │
│  │  │  (PHP-Apache)│    │ (MariaDB 10.11)│    │                │         │  │
│  │  │  port 80     │    │  port 3306   │    │  port 80       │         │  │
│  │  └──────┬───────┘    └──────┬───────┘    └────────────────┘         │  │
│  │         │   réseau bridge "glpi-net"                                 │  │
│  │         └───────────┬─────────────────────┐                          │  │
│  │                     ▼                     ▼                          │  │
│  │   /var/www/html/glpi/files     /var/lib/mysql                        │  │
│  │       (volume bind)              (volume bind)                       │  │
│  └─────────────┬───────────────────────┬────────────────────────────────┘  │
│                │ /vagrant (synced)     │                                    │
│                ▼                       ▼                                    │
│   ./data/glpi_data/            ./data/mysql_data/                          │
│   (persisté sur l'hôte)        (persisté sur l'hôte)                       │
└────────────────────────────────────────────────────────────────────────────┘
```

### Mode PROD (VPS — glpi.saiddev.fr)

```
   Internet ──► :443/HTTPS ──► ┌──────────────┐
   Internet ──► :80 (redir) ──►│   Traefik    │── ACME ──► Let's Encrypt
                               │   v3.1       │
                               └──────┬───────┘
                                      │ réseau "web" (externe)
                               ┌──────▼───────┐
                               │  glpi-app    │ (sans port hôte exposé)
                               └──────┬───────┘
                                      │ réseau "glpi-net" (interne)
                               ┌──────▼───────┐
                               │   glpi-db    │
                               └──────────────┘
                               (phpmyadmin désactivé en prod)
```

---

## Choix techniques justifiés

| Décision                        | Justification                                                        |
|---------------------------------|----------------------------------------------------------------------|
| **Docker Compose** vs install native | Reproductibilité, isolation, mise à jour atomique (`pull` + `up -d`) |
| **Image `diouxx/glpi`**         | Maintenue, ARM+x64, GLPI 10 prêt, configuration via env vars        |
| **MariaDB 10.11 LTS**           | Compatible GLPI 10, support jusqu'en 2028                           |
| **Wrapper Vagrant**             | Démo jury identique sur tout poste sans installer Docker à la main  |
| **`docker-compose.prod.yml` séparé** | Pas de Traefik en dev (allègement), surcouche prod claire       |
| **Bind mount `./data/`**        | Données visibles, sauvegardables, indépendantes de la VM            |
| **Healthcheck DB + `service_healthy`** | Évite GLPI qui démarre trop tôt avant MariaDB ready          |
| **`.env` gitignored**           | Mots de passe jamais en clair sur GitHub                            |
| **phpMyAdmin via `profiles: admin`** | Désactivé par défaut en prod, activable à la demande           |

---

## Sécurité

### Implémentée

- ✅ Mots de passe externalisés (`.env` non versionné)
- ✅ Réseau Docker interne pour MariaDB (pas exposé)
- ✅ HTTPS forcé en prod (Let's Encrypt + redirection 301)
- ✅ Headers sécurité Traefik : HSTS 1 an, X-Frame-Options DENY, nosniff, referrer-policy
- ✅ phpMyAdmin désactivé par défaut en prod (profil)
- ✅ Healthchecks pour éviter race conditions
- ✅ Comptes par défaut listés explicitement comme « à changer immédiatement »

### Recommandations post-déploiement

- 🔐 Changer les 4 mots de passe par défaut au premier login
- 🔐 Activer la 2FA sur compte super-admin
- 🔐 Configurer fail2ban sur le VPS (jail SSH + jail GLPI auth)
- 🔐 Sauvegardes planifiées + copie hors-site (rsync vers Backblaze B2 ou S3)
- 🔐 Mise à jour mensuelle GLPI (`scripts/update_glpi.sh`)
- 🔐 Monitoring : Uptime Kuma / Healthchecks.io ping

---

## PCA / PRA

| Scénario                | Procédure                                                  | RTO  | RPO  |
|-------------------------|------------------------------------------------------------|------|------|
| Corruption BDD          | `scripts/restore.sh ./backups/<date>`                      | 15 min | 24 h |
| Perte VPS complète      | Reprovision VPS + `git clone` + `restore.sh` depuis backup distant | 1 h   | 24 h |
| Mauvaise mise à jour    | `restore.sh` (sauvegarde auto par `update_glpi.sh`)         | 5 min | 0 (snapshot pré-update) |
| Compromission compte    | Désactivation utilisateur + audit logs `glpi_logs`         | 5 min | -    |

---

## Mapping référentiel BTS SIO 2026 (option SISR)

| Compétence                           | Élément du lab                                          |
|--------------------------------------|---------------------------------------------------------|
| **B1.1 Gérer le patrimoine info.**   | Inventaire GLPI (sites, modèles, ordinateurs, contrats) |
| **B1.2 Répondre aux incidents/dem.** | Gestion tickets ITIL, catégories, statuts, SLA          |
| **B1.3 Présence en ligne**           | Sous-domaine HTTPS public glpi.saiddev.fr               |
| **B2.1 Concevoir une solution**      | Choix Docker Compose vs alternatives, schéma            |
| **B2.4 Installer/configurer**        | Provisioning automatisé Vagrant + Compose               |
| **B2.6 Exploiter, dépanner**         | Scripts backup/restore/update + validate                |
| **B3.1 Sécuriser les équipements**   | HTTPS, headers sécurité, .env, isolation réseau         |

---

## Inspiration & crédits

- Repo origine : [Mediaschool-IRIS-BTS-SISR-2025/Serveur_GLPI_Louka](https://github.com/Mediaschool-IRIS-BTS-SISR-2025/Serveur_GLPI_Louka) — Louka Lavenir
- Image GLPI : [diouxx/glpi](https://hub.docker.com/r/diouxx/glpi)
- Documentation officielle GLPI : https://glpi-project.org/documentation/
