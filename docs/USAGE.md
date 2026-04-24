# 📖 USAGE.md — Premiers pas avec GLPI

## 1. Connexion

→ http://localhost:8080 (ou https://glpi.saiddev.fr en prod)

| Login       | Mot de passe | Profil                    |
|-------------|--------------|---------------------------|
| `glpi`      | `glpi`       | Super-Admin               |
| `tech`      | `tech`       | Technicien                |
| `normal`    | `normal`     | Utilisateur (créateur)    |
| `post-only` | `postonly`   | Création de tickets seule |

> ⚠ **Première action obligatoire** : changer les 4 mots de passe.
> Administration → Utilisateurs → cliquer sur l'utilisateur → onglet « Mot de passe ».

---

## 2. Charger les données démo Kiné@dom

```bash
vagrant ssh
cd /vagrant
bash scripts/seed-demo-data.sh
```

Injecte :
- 4 sites (Siège / Nice / Cannes / Télétravail)
- 5 fabricants
- 8 ordinateurs (PC accueil, compta, RH, kinés portables, serveur fichiers)
- 6 catégories ITIL
- 7 tickets de démonstration (variés : statuts, priorités, catégories)

---

## 3. Parcours type « technicien helpdesk »

1. **Inventaire** → Parc → Ordinateurs → vérifier les 8 PCs
2. **Tickets** → Assistance → Tickets → ouvrir un nouveau / suivre les existants
3. **Statuts** : Nouveau → En cours (attribué) → Résolu → Clos
4. **Catégories** : associer chaque ticket à une catégorie ITIL
5. **SLA** : Configuration → SLA → créer un SLA « 4h ouvrées »
6. **Notifications** : Configuration → Notifications → activer les mails (SMTP à configurer)

---

## 4. Sauvegardes

```bash
# Sauvegarde manuelle
bash scripts/backup.sh
# → ./backups/20260424_143012/glpidb.sql.gz + glpi_files.tar.gz

# Restauration
bash scripts/restore.sh ./backups/20260424_143012
```

Rotation automatique : seules les **7 dernières** sauvegardes sont conservées.

---

## 5. Mise à jour GLPI

```bash
bash scripts/update_glpi.sh
```

Effectue : backup préventif → `docker compose pull` → `up -d` → migrations BDD via `bin/console db:update`.

---

## 6. FAQ

**Q : Mes données sont-elles perdues si je `vagrant destroy` ?**
Non. Les volumes `data/mysql_data/` et `data/glpi_data/` sont sur l'hôte. Un nouveau `vagrant up` les retrouve.

**Q : Comment changer le port d'exposition ?**
Éditer `docker-compose.yml`, section `glpi.ports` : `"8080:80"` → `"<ton-port>:80"`. Puis `docker compose up -d`.

**Q : Comment ajouter un plugin GLPI (FusionInventory, etc.) ?**
Copier l'archive dans `data/glpi_data/plugins/`, redémarrer le conteneur (`docker compose restart glpi`), puis Configuration → Plugins → activer.

**Q : Comment voir les logs ?**
```bash
docker compose logs -f glpi      # live GLPI
docker compose logs --tail 100 db
```

**Q : phpMyAdmin doit-il rester accessible en prod ?**
**Non**. La config `prod` le désactive (profil `admin`). Pour y accéder ponctuellement :
```bash
ssh -L 8081:localhost:8081 user@glpi.saiddev.fr
docker compose --profile admin up -d phpmyadmin
```
