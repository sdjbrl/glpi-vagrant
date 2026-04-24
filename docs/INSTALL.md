# 📥 INSTALL.md — Installation du lab GLPI

## Pré-requis communs

| Outil       | Version mini | Vérif                  |
|-------------|--------------|------------------------|
| Git         | 2.30+        | `git --version`        |
| (Vagrant)   | 2.4+         | `vagrant --version`    |
| (VirtualBox)| 7.0+         | `VBoxManage --version` |
| (Docker)    | 24+          | `docker --version`     |
| (Compose v2)| 2.20+        | `docker compose version` |

➡️ **Mode Vagrant** : Vagrant + VirtualBox suffisent.
➡️ **Mode Docker direct** : seul Docker + Compose v2 sont nécessaires.

---

## Mode 1 — Lab local via Vagrant (jury / démo)

```bash
git clone https://github.com/sdjbrl/glpi-vagrant.git
cd glpi-vagrant
vagrant up
```

Durée : ~5–10 min (5 min de plus si box `bento/debian-12` non cachée).

À la fin, ouvrir :
- 🌐 **GLPI** : http://localhost:8080 (login `glpi` / `glpi`)
- 🛠 **phpMyAdmin** : http://localhost:8081 (root / mot de passe du `.env`)

Commandes utiles :
```bash
vagrant ssh                                  # entrer dans la VM
vagrant halt                                 # arrêter
vagrant destroy -f                           # supprimer
vagrant provision --provision-with validate  # rejouer la validation
```

---

## Mode 2 — Lab local via Docker Compose direct

Sans Vagrant, sur n'importe quel poste avec Docker installé.

```bash
git clone https://github.com/sdjbrl/glpi-vagrant.git
cd glpi-vagrant
cp .env.example .env
# ✏ éditer .env (mots de passe forts !)
docker compose up -d
docker compose ps
```

Mêmes URLs que ci-dessus.

---

## Mode 3 — Production VPS OVH (glpi.saiddev.fr) {#production-vps}

### A. Commande VPS OVH conseillée

| Gamme         | RAM   | vCPU | Disque | Prix HT/mois | Verdict pour GLPI |
|---------------|-------|------|--------|--------------|-------------------|
| VPS **VLE-2** | 2 Go  | 1    | 40 Go SSD | ~3,50 €   | ✅ OK pour <50 utilisateurs |
| VPS **Value** | 4 Go  | 2    | 80 Go SSD | ~6 €      | 🥇 confort + marge |
| VPS Essential | 8 Go  | 4    | 160 Go    | ~12 €     | overkill           |

➡️ Choisir **Debian 12** comme image système à la commande.

### B. Configuration DNS (manager OVH)

Dans **Domaines → saiddev.fr → Zone DNS**, ajouter :

| Sous-domaine | Type | Cible          |
|--------------|------|----------------|
| `glpi`       | A    | `<IP-VPS-OVH>` |
| `glpi`       | AAAA | `<IPv6-VPS>` (optionnel) |

Propagation : 5 min à 1 h. Vérifier : `dig glpi.saiddev.fr +short`

### C. Pré-requis VPS

- VPS Debian 12 (commandé ci-dessus)
- Ports **80** + **443** ouverts → par défaut OK chez OVH (firewall réseau désactivé)
  - Si firewall activé : Manager OVH → VPS → Firewall réseau → règles 80/443 IN ACCEPT

### D. Hardening initial du VPS OVH

```bash
ssh debian@<IP-VPS>          # ou root@ selon image OVH
sudo apt update && sudo apt -y full-upgrade

# Utilisateur dédié + clé SSH
sudo adduser said
sudo usermod -aG sudo said
sudo mkdir -p /home/said/.ssh
sudo cp ~/.ssh/authorized_keys /home/said/.ssh/
sudo chown -R said: /home/said/.ssh && sudo chmod 700 /home/said/.ssh

# Désactiver login root + password (édition /etc/ssh/sshd_config)
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# UFW + fail2ban
sudo apt -y install ufw fail2ban
sudo ufw allow OpenSSH && sudo ufw allow 80 && sudo ufw allow 443
sudo ufw --force enable
sudo systemctl enable --now fail2ban
```

### E. Installation Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# se déconnecter / reconnecter
```

### F. Déploiement

```bash
git clone https://github.com/sdjbrl/glpi-vagrant.git
cd glpi-vagrant

# 1. Réseau partagé pour Traefik
docker network create web

# 2. Configurer .env
cp .env.example .env
nano .env
#  → MYSQL_ROOT_PASSWORD=<mot-de-passe-fort>
#  → MYSQL_PASSWORD=<mot-de-passe-fort>
#  → DOMAIN_NAME=saiddev.fr
#  → ACME_EMAIL=said@saiddev.fr

# 3. Lancement (DEV + surcouche PROD)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 4. Vérifier les certificats Let's Encrypt
docker compose logs traefik | grep -i acme
```

➡ Au bout de 30–60 secondes, https://glpi.saiddev.fr doit servir GLPI.

### G. Première sécurisation post-install

1. Login `glpi/glpi` → **changer immédiatement** les 4 comptes par défaut
2. Configuration → Générale → Sécurité : forcer HTTPS, complexité mots de passe
3. Supprimer le fichier `install/install.php` (déjà fait par l'image diouxx)
4. Activer la 2FA sur le compte super-admin
5. Configurer une sauvegarde planifiée (cron du VPS appelant `scripts/backup.sh`)

```bash
# Exemple cron : sauvegarde quotidienne à 03:00
crontab -e
# 0 3 * * * cd /opt/glpi-vagrant && bash scripts/backup.sh >> /var/log/glpi-backup.log 2>&1
```

---

## ⚠ Pourquoi pas Vercel ?

Vercel est une plateforme **serverless / static** (Next.js, Remix, fonctions edge).
Elle ne peut **pas** exécuter :
- des conteneurs Docker persistants (GLPI tourne en PHP-FPM continu)
- une base MariaDB
- du stockage de fichiers persistant

Pour `glpi.saiddev.fr`, choisir **un VPS** : OVH (3,50 €/mois), Hetzner CX22 (4 €), Scaleway DEV1-S, IONOS, Contabo. C'est ce que fait n'importe quel hébergement GLPI réel.

Vercel reste parfait pour ton **portfolio statique** (`sdjbrl.me`).

---

## 🆘 Troubleshooting

| Symptôme                                    | Cause probable / solution                                         |
|---------------------------------------------|-------------------------------------------------------------------|
| `vagrant up` : VERR_ACCESS_DENIED           | Mauvais machinefolder VBox → `VBoxManage setproperty machinefolder "C:\Users\<toi>\VirtualBox VMs"` |
| `docker compose up` : port 80 already in use| Apache/Nginx local → arrêter, ou changer le port hôte             |
| GLPI : "Erreur connexion BDD"               | Attendre 30 s (healthcheck), ou vérifier `.env` cohérent          |
| Traefik : pas de cert Let's Encrypt         | DNS pas propagé, ou port 80 fermé, ou rate limit (5 certs/semaine)|
| `glpi-app` boucle redémarrage               | `docker compose logs glpi` — souvent perms sur `data/glpi_data/`  |
