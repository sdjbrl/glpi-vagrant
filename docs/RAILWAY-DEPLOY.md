# Déploiement GLPI sur Railway

> Guide test rapide en attendant la livraison du VPS OVH.
> Railway = PaaS (PHP/Docker managé), HTTPS auto, ~5–8 €/mois pour ce stack.

---

## 1. Pré-requis

- Compte Railway lié à GitHub ✅ (déjà fait)
- Repo GitHub contenant ce dossier `glpi-vagrant/` (public ou privé)
- Optionnel : sous-domaine `glpi.saiddev.fr` à pointer vers Railway

---

## 2. Architecture sur Railway

```
┌──────────────────── Project "glpi-saiddev" ────────────────────┐
│                                                                │
│   ┌─────────────────┐         ┌──────────────────────────┐     │
│   │  Service: glpi  │ ──────► │  Service: mariadb        │     │
│   │  (Dockerfile)   │  TCP    │  (template officiel)     │     │
│   │  Port public    │  3306   │  Volume persistant       │     │
│   └────────┬────────┘         └──────────────────────────┘     │
│            │ HTTPS                                              │
│            ▼                                                    │
│   glpi-xxx.up.railway.app  →  CNAME glpi.saiddev.fr            │
└────────────────────────────────────────────────────────────────┘
```

Deux services dans le **même projet Railway**, reliés par variables internes.

---

## 3. Étapes pas-à-pas

### A. Pousser le code sur GitHub

Si pas encore fait :

```powershell
cd C:\Users\djibril\prtfl\glpi-vagrant
git init
git add .
git commit -m "feat: lab GLPI Vagrant + déploiement Railway"
# créer le repo sur github.com/sdjbrl/glpi-vagrant puis :
git remote add origin https://github.com/sdjbrl/glpi-vagrant.git
git branch -M main
git push -u origin main
```

### B. Créer le projet Railway + base MariaDB

1. https://railway.app → **New Project**
2. **Provision MariaDB** (template officiel — bouton "+ New" → "Database" → "MariaDB")
3. Attendre 30 s que le service soit prêt
4. Cliquer sur le service MariaDB → onglet **Variables** : Railway a généré
   - `MARIADB_ROOT_PASSWORD`
   - `MARIADB_USER` = `mariadb`
   - `MARIADB_PASSWORD`
   - `MARIADB_DATABASE` = `railway`

### C. Créer la base GLPI dans MariaDB

Onglet **Data** du service MariaDB → **Query** :

```sql
CREATE DATABASE glpi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'glpi'@'%' IDENTIFIED BY 'CHANGE_MOI_MOT_DE_PASSE_FORT';
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'%';
FLUSH PRIVILEGES;
```

> Note le mot de passe `glpi`, on le réutilise à l'étape suivante.

### D. Ajouter le service GLPI

1. Dans le projet → **+ New** → **GitHub Repo** → choisir `sdjbrl/glpi-vagrant`
2. Railway détecte `railway.json` → build via `railway/Dockerfile`
3. Onglet **Variables** du service GLPI, ajouter :

| Variable          | Valeur                                          |
|-------------------|-------------------------------------------------|
| `MYSQLHOST`       | `${{MariaDB.RAILWAY_PRIVATE_DOMAIN}}`           |
| `MYSQLPORT`       | `3306`                                          |
| `MYSQLUSER`       | `glpi`                                          |
| `MYSQLPASSWORD`   | `<le mot de passe défini en C>`                 |
| `MYSQLDATABASE`   | `glpi`                                          |
| `TIMEZONE`        | `Europe/Paris`                                  |
| `PORT`            | `80`                                            |

> La syntaxe `${{MariaDB.XXX}}` référence une variable d'un autre service du
> même projet — Railway résout ça automatiquement à chaque déploiement.

### E. Activer le domaine public

Service GLPI → **Settings** → **Networking** → **Generate Domain** → tu obtiens
`glpi-production-XXXX.up.railway.app` (HTTPS auto).

### F. Vérifier le déploiement

1. Onglet **Deployments** → attendre que le build passe au vert (~3–5 min la 1re fois)
2. **View Logs** → tu dois voir :
   ```
   [railway] DB_HOST=mariadb.railway.internal  DB_NAME=glpi  PORT=80
   [railway] Démarrage GLPI...
   ```
3. Ouvrir l'URL publique → assistant d'install GLPI s'affiche
4. Suivre l'assistant : choisir **MySQL/MariaDB**, host = `${MYSQLHOST}`,
   user = `glpi`, db = `glpi` (Railway les a déjà injectées)

### G. Sécurisation post-install

⚠ **Immédiatement après le 1er login** (`glpi` / `glpi`) :

- Changer les 4 mots de passe par défaut : `glpi`, `tech`, `normal`, `post-only`
- Configuration → Générale → activer 2FA TOTP
- Configuration → Authentification → politique mots de passe : 12 chars min
- Supprimer le fichier `install/install.php` (impossible via Railway → ouvrir
  un shell dans la console Railway puis `rm /var/www/html/glpi/install/install.php`)

---

## 4. Domaine custom `glpi.saiddev.fr`

### Sur Railway
Service GLPI → **Settings** → **Custom Domain** → entrer `glpi.saiddev.fr` →
Railway affiche un CNAME du type `xyz.up.railway.app`.

### Sur OVH (zone DNS de saiddev.fr)
```
Type   : CNAME
Sous-domaine : glpi
Cible  : xyz.up.railway.app.   (point final !)
TTL    : 60
```

Propagation 2-10 min. HTTPS Let's Encrypt fourni par Railway sans action.

---

## 5. Sauvegardes

Railway sauvegarde automatiquement le volume MariaDB (snapshots quotidiens
sur plan Pro). En Hobby, **dump manuel** depuis ton poste :

```bash
# Récupère l'URL publique de la DB (Railway → MariaDB → Variables → MYSQL_PUBLIC_URL)
mysqldump --single-transaction \
  -h <PUBLIC_HOST> -P <PUBLIC_PORT> \
  -u glpi -p<MOT_DE_PASSE> \
  glpi | gzip > glpi-railway-$(date +%F).sql.gz
```

> Ou garde les sauvegardes via le script `scripts/backup.sh` adapté (variables
> d'env Railway au lieu de localhost).

---

## 6. Coûts attendus

| Ressource          | Conso typique   | Coût Hobby (5 $ inclus) |
|--------------------|-----------------|--------------------------|
| GLPI (Apache+PHP)  | 200–400 Mo RAM  | ~3 $/mois                |
| MariaDB            | 150–300 Mo RAM  | ~2 $/mois                |
| Bande passante     | <10 Go/mois     | inclus                   |
| **Total**          |                 | **~5–7 $/mois**          |

Le crédit Hobby couvre **largement** les premiers tests. Au-delà : facturation
à l'usage.

---

## 7. Limitations Railway vs OVH

| Aspect                | Railway                       | OVH VPS                |
|-----------------------|-------------------------------|------------------------|
| Setup                 | 10 min                        | 30-60 min              |
| HTTPS                 | Auto (Let's Encrypt managé)   | Traefik à configurer   |
| Backups               | Snapshots auto (Pro)          | À scripter (cron)      |
| Personnalisation OS   | ❌ Non (PaaS)                 | ✅ Totale (root)       |
| Coût stable           | 5–10 $/mois (variable)        | 6,62 €/mois (fixe)     |
| Démontre compétences SISR | Moyen (managé)            | Fort (sysadmin)        |

**Stratégie** : Railway pour valider rapidement → OVH pour la prod soutenance.

---

## 8. Rollback / suppression

```
Railway dashboard → Project → Settings → Delete Project
```

Ou via CLI :
```bash
npm i -g @railway/cli
railway login
railway down
```

---

## 9. Troubleshooting

**Build échoue : `unable to find image diouxx/glpi`**
→ Docker Hub rate-limit. Re-déployer 5 min plus tard ou utiliser un mirror.

**App répond 502 Bad Gateway**
→ Apache n'écoute pas sur `$PORT`. Vérifier les logs : le script
`railway-entrypoint.sh` doit afficher la ligne de patch port.

**GLPI : "Erreur de connexion à la base"**
→ Variable `MYSQLHOST` mal référencée. Doit être
`${{MariaDB.RAILWAY_PRIVATE_DOMAIN}}` (réseau interne Railway, gratuit) et
PAS `MYSQL_PUBLIC_URL` (facturé en bande passante).

**Cold start lent (>30s)**
→ Hobby n'a pas de scaling-zero garanti, mais l'app reste up. Si dort :
upgrade Pro (20 $/mois) ou ping cron toutes les 5 min via UptimeRobot.

---

## 10. Aller plus loin

- [Railway docs](https://docs.railway.app)
- [Railway templates](https://railway.app/templates) — chercher "GLPI" si
  un template communautaire est dispo
- Quand le VPS OVH est prêt → suivre `OVH-DEPLOY.md` et migrer la base
  via `mysqldump` / `mysql` import

---

**Auteur** : Saïd AHMED MOUSSA — BTS SIO SISR 2026
