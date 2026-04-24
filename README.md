# 📦 glpi-vagrant — Lab GLPI 10 reproductible (Docker + Vagrant)

> **Auteur** : Saïd AHMED MOUSSA (sdjbrl) — RP BTS SIO SISR 2026
> **Cible production** : `glpi.saiddev.fr`
> **Inspiration** : [Mediaschool-IRIS-BTS-SISR-2025/Serveur_GLPI_Louka](https://github.com/Mediaschool-IRIS-BTS-SISR-2025/Serveur_GLPI_Louka) (Louka Lavenir)
> **Contexte portfolio** : reproduction du parc helpdesk de mon alternance Kiné@dom (07/10/2024 → 10/07/2025)

---

## 🎯 Objectif

Permettre à **n'importe qui** (jury, recruteur, devops) de monter en **une seule commande** un GLPI 10 fonctionnel et pré-rempli avec un parc de démonstration, identique à celui géré chez Kiné@dom :

```bash
git clone https://github.com/sdjbrl/glpi-vagrant.git
cd glpi-vagrant
vagrant up                # ~5-10 min
# 🌐 GLPI : http://localhost:8080  (glpi/glpi)
```

Pas besoin d'installer Apache, PHP, MariaDB ni GLPI à la main : tout est conteneurisé et orchestré.

---

## 🧱 Stack

| Service       | Image              | Port hôte | Rôle                          |
|---------------|--------------------|-----------|-------------------------------|
| `glpi-app`    | `diouxx/glpi`      | 8080      | Interface web GLPI 10         |
| `glpi-db`     | `mariadb:10.11`    | (interne) | Base de données               |
| `glpi-pma`    | `phpmyadmin`       | 8081      | Admin BDD (dev uniquement)    |

Wrapper : **Vagrant** (Debian 12 bento) → **Docker Compose v2**.

---

## 📁 Arborescence

```
glpi-vagrant/
├── Vagrantfile               # Définit la VM Debian 12 + provisioners
├── docker-compose.yml        # Stack DEV (ports exposés en localhost)
├── docker-compose.prod.yml   # Surcouche PROD (Traefik + HTTPS Let's Encrypt)
├── .env.example              # Modèle de variables (mots de passe, domaine)
├── .gitignore                # Exclut data/ .env *.log .vagrant/
│
├── provision/
│   ├── 01-base.sh            # apt, timezone, MOTD
│   ├── 02-docker.sh          # Docker Engine + Compose v2 (repo officiel)
│   ├── 03-compose-up.sh      # docker compose up -d
│   └── 99-validate.sh        # 11 checks [OK]/[KO]
│
├── scripts/
│   ├── backup.sh             # Dump SQL + tar fichiers, rotation 7j
│   ├── restore.sh            # Restauration depuis ./backups/<date>/
│   ├── update_glpi.sh        # Backup → pull → up -d → migrations
│   └── seed-demo-data.sh     # Parc démo Kiné@dom (8 PCs, 7 tickets, 4 sites)
│
├── configs/
│   ├── php/glpi-custom.ini   # memory_limit 256M, upload 32M, tz Paris
│   └── mariadb/glpi-tuning.cnf
│
├── data/                     # ⚠ Persistant, gitignored
│   ├── mysql_data/
│   └── glpi_data/
│
└── docs/
    ├── INSTALL.md            # Pré-requis + 3 modes de déploiement
    ├── USAGE.md              # Comptes, premières actions, FAQ
    ├── CONFIG.md             # Variables .env, ports, volumes
    └── ARCHITECTURE.md       # Schéma + choix techniques + sécurité
```

---

## 🚀 Déploiement rapide (3 modes)

### 1. Local via **Vagrant** (recommandé pour démo / jury)
```bash
vagrant up
# ouvre http://localhost:8080
```

### 2. Local via **Docker Compose** uniquement (sans Vagrant)
```bash
cp .env.example .env       # édite les mots de passe
docker compose up -d
```

### 3. **Production** sur VPS (glpi.saiddev.fr)
Voir [`docs/INSTALL.md`](docs/INSTALL.md#production-vps) — déploiement Traefik + HTTPS auto Let's Encrypt :
```bash
docker network create web
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 🔐 Comptes par défaut (à changer immédiatement)

| Login       | Password    | Profil                |
|-------------|-------------|-----------------------|
| `glpi`      | `glpi`      | Super-Admin           |
| `tech`      | `tech`      | Technicien            |
| `normal`    | `normal`    | Utilisateur           |
| `post-only` | `postonly`  | Création tickets seul |

---

## 🛠 Maintenance

| Opération        | Commande                                  |
|------------------|-------------------------------------------|
| Sauvegarde       | `bash scripts/backup.sh`                  |
| Restauration     | `bash scripts/restore.sh ./backups/<dt>`  |
| Mise à jour GLPI | `bash scripts/update_glpi.sh`             |
| Données démo     | `bash scripts/seed-demo-data.sh`          |
| Validation       | `vagrant ssh -c "bash /vagrant/provision/99-validate.sh"` |

---

## 📚 Documentation détaillée

- [`docs/INSTALL.md`](docs/INSTALL.md) — Installation pas à pas (dev + VPS)
- [`docs/OVH-DEPLOY.md`](docs/OVH-DEPLOY.md) — 🌐 **Guide complet déploiement OVH → glpi.saiddev.fr**
- [`docs/RAILWAY-DEPLOY.md`](docs/RAILWAY-DEPLOY.md) — 🚂 **Déploiement test rapide sur Railway (PaaS)**
- [`docs/USAGE.md`](docs/USAGE.md) — Premiers pas, comptes, FAQ
- [`docs/CONFIG.md`](docs/CONFIG.md) — Variables, ports, volumes
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Schéma, sécurité, choix techniques

---

## 🆚 Différences vs le repo de Louka

| Point                              | Louka (original) | Ce repo                                |
|------------------------------------|------------------|----------------------------------------|
| Bug indentation `labels:`          | ❌ présent       | ✅ corrigé                             |
| Healthcheck MariaDB                | ❌               | ✅ + `service_healthy` dependency      |
| Stack autonome sans Traefik        | ❌ (couplé Traefik) | ✅ + variante prod séparée          |
| Scripts backup/restore/update      | mentionnés README, absents | ✅ implémentés                |
| Conf PHP/MariaDB tunée             | ❌               | ✅ (`configs/php`, `configs/mariadb`)  |
| Wrapper Vagrant reproductible      | ❌               | ✅                                     |
| Validation auto post-déploiement   | ❌               | ✅ 11 checks                           |
| Données démo contextualisées       | ❌               | ✅ Kiné@dom (8 PCs / 7 tickets ITIL)   |
| Documentation complète             | partielle        | ✅ 4 docs                              |
| Headers sécurité prod              | ❌               | ✅ HSTS, X-Frame, nosniff, referrer    |

---

## 🎓 Cadre BTS SIO 2026

Ce lab matérialise les compétences suivantes du référentiel :

- **B1.1** — Gérer le patrimoine informatique → inventaire GLPI (sites, modèles, ordinateurs)
- **B1.2** — Répondre aux incidents et demandes → tickets ITIL, catégories, statuts
- **B1.3** — Développer la présence en ligne → exposition web sur sous-domaine
- **B2.1 / B2.4** — Conception/installation/configuration solution réseau (Docker Compose)

📌 Voir [`projects/kineadom.html`](https://sdjbrl.me/projects/kineadom.html) sur le portfolio pour le contexte complet.
