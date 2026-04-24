# 🌐 OVH-DEPLOY.md — Guide complet de déploiement sur VPS OVH

> **Cible** : `https://glpi.saiddev.fr`
> **Prérequis** : un compte OVHcloud + domaine `saiddev.fr` géré chez OVH (ou ailleurs)
> **Durée totale** : ~45 min (commande VPS → GLPI accessible en HTTPS)
> **Coût** : à partir de 3,50 € HT/mois (VPS VLE-2)

---

## 🗺 Vue d'ensemble (étapes)

```
1. Commander le VPS OVH                    (~10 min)
2. Configurer la zone DNS du domaine       (~5 min, propagation 5-60 min)
3. Première connexion + hardening SSH      (~10 min)
4. Installation Docker                     (~5 min)
5. Cloner ce repo + configurer .env        (~5 min)
6. Lancer la stack avec Traefik            (~5 min)
7. Sécurisation post-install GLPI          (~5 min)
8. Sauvegardes automatiques + monitoring   (bonus)
```

---

## 1️⃣ Commander le VPS OVH

### 1.1 Choisir l'offre

→ https://www.ovhcloud.com/fr/vps/

| Gamme         | RAM   | vCPU | Disque    | Prix HT/mois | Recommandation         |
|---------------|-------|------|-----------|--------------|------------------------|
| VPS **VLE-2** | 2 Go  | 1    | 40 Go SSD | ~3,50 €      | ✅ POC / <50 utilisateurs |
| VPS **Value** | 4 Go  | 2    | 80 Go SSD | ~6 €         | 🥇 **Conseillé** prod   |
| VPS Essential | 8 Go  | 4    | 160 Go    | ~12 €        | overkill pour GLPI     |

➡️ **Recommandation pour `glpi.saiddev.fr`** : *VPS Value* (marge confortable, stack 3 conteneurs + futurs plugins).

### 1.2 Configuration à la commande

| Champ                          | Valeur                                           |
|--------------------------------|--------------------------------------------------|
| **Datacenter**                 | Gravelines (GRA) ou Roubaix (RBX) — France       |
| **Système d'exploitation**     | **Debian 12** (image OVH récente)                |
| **Distribution**               | "Debian 12 (clean install)" — sans panel         |
| **Sauvegarde automatisée**     | Optionnel (+~1 €/mois, snapshots nocturnes)      |
| **IP supplémentaire / IPv6**   | IPv6 incluse ✅                                  |
| **Engagement**                 | Mensuel pour commencer (sans engagement)         |

Validation paiement → email de provisioning sous 5–15 min avec :
- IP publique (ex. `51.91.xxx.xxx`)
- Identifiants SSH initial (`debian` ou `ubuntu` selon image, ou root + mdp temporaire)

---

## 2️⃣ Configurer la zone DNS

### 2.1 Si `saiddev.fr` est chez OVH

→ Manager OVH → **Web Cloud** → **Noms de domaine** → `saiddev.fr` → **Zone DNS** → **Ajouter une entrée**

| Champ         | Valeur                  |
|---------------|-------------------------|
| Type          | **A**                   |
| Sous-domaine  | `glpi`                  |
| TTL           | 0 (par défaut)          |
| Cible         | `<IP-publique-VPS>`     |

(optionnel) Ajouter aussi un **AAAA** avec l'IPv6 du VPS.

### 2.2 Si `saiddev.fr` est chez un autre registrar (Namecheap, Cloudflare, Gandi…)

Même principe, ajouter dans la zone DNS du domaine :
```
glpi    IN    A      <IP-publique-VPS>
glpi    IN    AAAA   <IPv6-VPS>            (optionnel)
```

### 2.3 Vérifier la propagation

```bash
dig glpi.saiddev.fr +short
# doit retourner l'IP du VPS

# Alternative en ligne :
# https://dnschecker.org/#A/glpi.saiddev.fr
```

⏳ Délai : généralement 5 min, max 1 h. **Attendre la propagation avant l'étape 6** (sinon Let's Encrypt échouera).

---

## 3️⃣ Première connexion + hardening SSH

### 3.1 Se connecter en SSH

```bash
ssh debian@<IP-VPS>
# ou : ssh root@<IP-VPS> selon l'image OVH (mot de passe envoyé par email)
```

À la première connexion root : **changer immédiatement le mot de passe**
```bash
passwd
```

### 3.2 Mise à jour système

```bash
sudo apt update && sudo apt -y full-upgrade
sudo apt -y install vim curl git ufw fail2ban
sudo timedatectl set-timezone Europe/Paris
```

### 3.3 Créer un utilisateur dédié + clé SSH

**Sur ton poste local** (Windows PowerShell ou WSL) :
```bash
# Si pas encore de clé SSH :
ssh-keygen -t ed25519 -C "said@saiddev.fr"
# Copier ta clé publique :
cat ~/.ssh/id_ed25519.pub
```

**Sur le VPS** :
```bash
sudo adduser said                      # mot de passe fort
sudo usermod -aG sudo said
sudo mkdir -p /home/said/.ssh
echo "<colle-ta-clé-publique-ici>" | sudo tee /home/said/.ssh/authorized_keys
sudo chown -R said:said /home/said/.ssh
sudo chmod 700 /home/said/.ssh
sudo chmod 600 /home/said/.ssh/authorized_keys
```

**Tester depuis ton poste** (nouveau terminal, sans fermer l'ancien) :
```bash
ssh said@<IP-VPS>          # doit fonctionner sans mot de passe
sudo whoami                # doit retourner "root"
```

### 3.4 Désactiver login root + password SSH

```bash
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### 3.5 Firewall UFW + fail2ban

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose

sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd       # vérifie la jail SSH active
```

### 3.6 (Optionnel mais conseillé) Changer le port SSH

```bash
sudo sed -i 's/^#*Port .*/Port 2222/' /etc/ssh/sshd_config
sudo systemctl restart ssh
sudo ufw delete allow OpenSSH
sudo ufw allow 2222/tcp
# Reconnexion : ssh -p 2222 said@<IP-VPS>
```

---

## 4️⃣ Installer Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker said
exit                                   # se déconnecter
ssh said@<IP-VPS>                       # se reconnecter (groupe docker actif)

docker --version                       # vérif
docker compose version
```

---

## 5️⃣ Cloner le repo + configurer `.env`

```bash
sudo mkdir -p /opt && cd /opt
sudo git clone https://github.com/sdjbrl/glpi-vagrant.git
sudo chown -R said:said glpi-vagrant
cd glpi-vagrant

cp .env.example .env
nano .env
```

**Compléter `.env`** :
```ini
MYSQL_ROOT_PASSWORD=<chaîne-aléatoire-32-caractères>
MYSQL_DATABASE=glpidb
MYSQL_USER=glpiuser
MYSQL_PASSWORD=<chaîne-aléatoire-32-caractères>

GLPI_VERSION=10.0.18
TZ=Europe/Paris

DOMAIN_NAME=saiddev.fr
ACME_EMAIL=said@saiddev.fr
```

💡 Générer des mots de passe forts :
```bash
openssl rand -base64 24
openssl rand -base64 24
```

---

## 6️⃣ Lancer la stack avec Traefik + HTTPS auto

```bash
cd /opt/glpi-vagrant

# Réseau Docker partagé pour Traefik
docker network create web

# Lancement (compose dev + surcouche prod)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Suivre l'obtention du certificat Let's Encrypt
docker compose logs -f traefik | grep -i acme
# Attendre ~30-60 s : "Server responded with a certificate"
```

### 6.1 Test

```bash
curl -I https://glpi.saiddev.fr
# HTTP/2 302 ... (redirection vers /index.php) ✅
```

→ Ouvrir https://glpi.saiddev.fr dans le navigateur. Page de login GLPI s'affiche en HTTPS.

### 6.2 Vérification cadenas

- 🔒 Certificat Let's Encrypt valide 90 jours
- Renouvellement automatique par Traefik (rien à faire)

---

## 7️⃣ Sécurisation post-install GLPI

### 7.1 Login + changement immédiat des 4 mots de passe par défaut

| Login       | Password initial | À changer ⚠ |
|-------------|------------------|-------------|
| `glpi`      | `glpi`           | OUI         |
| `tech`      | `tech`           | OUI         |
| `normal`    | `normal`         | OUI         |
| `post-only` | `postonly`       | OUI         |

→ Login `glpi/glpi` → **Administration** → **Utilisateurs** → cliquer chaque utilisateur → onglet **Mot de passe** → générer un mot de passe fort.

### 7.2 Activer la 2FA (super-admin)

→ **Mon profil** (icône en haut à droite) → onglet **Authentification à deux facteurs** → Activer TOTP → scanner QR code avec Authy/Google Authenticator.

### 7.3 Politique de mots de passe stricte

→ **Configuration** → **Générale** → onglet **Sécurité** :
- Longueur minimale : **12**
- Caractères requis : majuscules + minuscules + chiffres + symboles
- Expiration : 90 jours
- Verrouillage après 5 échecs

### 7.4 Désactiver l'install en local (déjà fait par l'image)

```bash
docker compose exec glpi ls /var/www/html/glpi/install/install.php
# → "No such file" attendu ✅
```

### 7.5 Headers sécurité (déjà appliqués par Traefik en prod)

Vérifier :
```bash
curl -I https://glpi.saiddev.fr | grep -iE 'strict-transport|x-frame|x-content|referrer'
# Doit lister : strict-transport-security, x-frame-options DENY, x-content-type-options nosniff, referrer-policy
```

---

## 8️⃣ Sauvegardes automatiques + monitoring

### 8.1 Cron quotidien de sauvegarde

```bash
sudo crontab -u said -e
```

Ajouter :
```cron
# Sauvegarde GLPI tous les jours à 03:15
15 3 * * * cd /opt/glpi-vagrant && bash scripts/backup.sh >> /var/log/glpi-backup.log 2>&1
```

Rotation : `scripts/backup.sh` conserve automatiquement les 7 dernières sauvegardes.

### 8.2 Copie hors-site (recommandé) — Backblaze B2 / S3

```bash
# Installer rclone
curl https://rclone.org/install.sh | sudo bash
rclone config         # configurer un remote B2/S3

# Ajouter au cron quotidien :
30 3 * * * rclone sync /opt/glpi-vagrant/backups b2:glpi-backups-saiddev
```

→ RPO = 24 h, RTO = 30 min depuis B2.

### 8.3 Monitoring uptime gratuit

→ https://healthchecks.io (gratuit jusqu'à 20 checks)
- Créer un check "GLPI saiddev"
- Récupérer l'URL ping
- Cron toutes les 5 min :
```cron
*/5 * * * * curl -fsS --retry 3 https://hc-ping.com/<UUID> > /dev/null
```

### 8.4 Mises à jour automatiques OS (security only)

```bash
sudo apt -y install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 8.5 Mise à jour mensuelle GLPI

```bash
cd /opt/glpi-vagrant
bash scripts/update_glpi.sh
```
(effectue backup → pull → recreate → migrations BDD)

---

## 🆘 Troubleshooting OVH

| Symptôme                                          | Solution                                                                  |
|---------------------------------------------------|---------------------------------------------------------------------------|
| `dig glpi.saiddev.fr` ne retourne rien            | DNS pas propagé (attendre) ou faute dans la zone DNS                      |
| Traefik : `acme: error 400 :: urn:ietf:params:acme:error:rateLimited` | Trop de tentatives Let's Encrypt — attendre 1 h, vérifier DNS d'abord |
| `connection refused` sur :80 / :443               | Firewall réseau OVH activé : Manager → VPS → Firewall → autoriser 80/443  |
| GLPI lent (page > 5 s)                            | Passer en VPS Value 4 Go RAM, ou ajouter `OPCache` PHP                    |
| `no space left on device`                         | `docker system prune -af --volumes` puis vérifier `df -h`                 |
| SSH bloqué par fail2ban après essais foirés       | Depuis console OVH : `sudo fail2ban-client unban <ton-IP>`                |
| Email Let's Encrypt expire bientôt                | Mettre à jour `ACME_EMAIL` dans `.env` puis `docker compose restart traefik` |

---

## 🎓 Pour la soutenance BTS

Argumentaire à préparer :

1. **Pourquoi un VPS et pas du PaaS (Vercel/Railway) ?**
   → Vercel = serverless statique, incompatible avec PHP+MariaDB. Railway aurait marché mais coûte plus cher (5-15 $/mois) et fait perdre les compétences SISR (sysadmin, hardening, reverse-proxy).

2. **Pourquoi OVH ?**
   → Hébergeur français (RGPD), datacenters en France, prix très compétitif, support FR.

3. **Comment tu as sécurisé le serveur ?**
   → SSH par clé uniquement (pas de password root), UFW, fail2ban, 2FA GLPI, HTTPS forcé, headers HSTS/X-Frame, sauvegardes auto + copie hors-site.

4. **Que fais-tu en cas de panne du VPS ?**
   → PRA documenté : reprovision VPS (10 min) + git clone + restore.sh depuis B2 (20 min) → RTO = 30 min, RPO = 24 h.

5. **Compétences mobilisées (référentiel BTS SIO 2026)** :
   - **B1.1** patrimoine (inventaire GLPI)
   - **B1.2** incidents (tickets ITIL)
   - **B1.3** présence en ligne (sous-domaine HTTPS)
   - **B2.1** conception solution (choix techniques justifiés)
   - **B2.4** installation/config (provisioning automatisé)
   - **B2.6** exploitation (backup, monitoring)
   - **B3.1** sécurisation (hardening complet)

---

## 📞 Liens utiles OVH

- Manager OVH : https://www.ovh.com/manager/
- Documentation VPS : https://help.ovhcloud.com/csm/fr-vps-getting-started
- Status OVH (incidents) : https://status.ovhcloud.com/
- Communauté : https://community.ovh.com/
