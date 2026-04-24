#!/bin/bash
# seed-demo-data.sh — Injecte un parc de démo (contexte Kiné@dom)
# À lancer APRÈS la première connexion à GLPI (initialisation des tables)
set -euo pipefail

cd "$(dirname "$0")/.."
source .env

DB_EXEC="docker compose exec -T db mariadb -u${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE}"

if ! ${DB_EXEC} -e "SELECT 1 FROM glpi_computers LIMIT 1" &>/dev/null; then
  echo "❌ Tables GLPI absentes. Connectez-vous une fois sur http://localhost:8080 pour initialiser."
  exit 1
fi

echo "▶ Injection sites Kiné@dom"
${DB_EXEC} <<'SQL'
INSERT IGNORE INTO glpi_locations (name, completename, entities_id) VALUES
  ('Siège Kiné@dom',  'Siège Kiné@dom',  0),
  ('Agence Nice',     'Agence Nice',     0),
  ('Agence Cannes',   'Agence Cannes',   0),
  ('Télétravail',     'Télétravail',     0);

INSERT IGNORE INTO glpi_manufacturers (name) VALUES
  ('Dell'),('HP'),('Lenovo'),('Apple'),('Brother');

INSERT IGNORE INTO glpi_computertypes (name)  VALUES ('Portable'),('Fixe'),('Serveur');
INSERT IGNORE INTO glpi_computermodels (name) VALUES ('Latitude 5520'),('EliteBook 840 G8'),('ThinkPad L14'),('MacBook Pro 13"');
SQL

echo "▶ Injection 8 ordinateurs"
${DB_EXEC} <<'SQL'
INSERT IGNORE INTO glpi_computers
  (name, serial, otherserial, locations_id, computermodels_id, computertypes_id, manufacturers_id, comment, entities_id)
VALUES
  ('PC-ACC-01',    'DLLS001','KAD-001',1,1,1,1,'Poste accueil siège',0),
  ('PC-COMPTA-02', 'DLLS002','KAD-002',1,1,1,1,'Poste comptabilité',0),
  ('PC-RH-03',     'HPEB001','KAD-003',1,2,1,2,'Poste RH',0),
  ('PC-DIR-04',    'MBP001', 'KAD-004',1,4,1,4,'MacBook direction',0),
  ('PC-KINE-05',   'LNV001', 'KAD-005',2,3,1,3,'Portable kiné Nice',0),
  ('PC-KINE-06',   'LNV002', 'KAD-006',2,3,1,3,'Portable kiné Nice',0),
  ('PC-KINE-07',   'LNV003', 'KAD-007',3,3,1,3,'Portable kiné Cannes',0),
  ('SRV-FILES-01', 'PE-T140','KAD-SRV',1,1,3,1,'Serveur fichiers Win 2022',0);
SQL

echo "▶ Injection catégories ITIL & tickets démo"
${DB_EXEC} <<'SQL'
INSERT IGNORE INTO glpi_itilcategories (name, completename, entities_id) VALUES
  ('Matériel','Matériel',0),('Logiciel','Logiciel',0),
  ('Réseau / WiFi','Réseau / WiFi',0),
  ('Compte / mot de passe','Compte / mot de passe',0),
  ('Imprimante','Imprimante',0),('Demande nouvelle','Demande nouvelle',0);

INSERT INTO glpi_tickets
  (name, content, status, priority, urgency, impact, type, itilcategories_id, locations_id, entities_id, date, date_creation)
VALUES
  ('Imprimante Brother HS - Nice',  'Voyant rouge, ne répond plus.',                        1,3,3,3,1,5,2,0,NOW(),NOW()),
  ('Mot de passe oublié - Dupont',   'Reset session matin.',                                 2,2,2,2,2,4,1,0,NOW(),NOW()),
  ('WiFi instable agence Cannes',    'Coupures toutes les 10 min, 4 personnes.',             2,4,4,4,1,3,3,0,NOW(),NOW()),
  ('Préparation poste embauche',     'Provisionner Lenovo + AD + mail pour P. Kiné lundi.',  1,3,3,3,2,6,3,0,NOW(),NOW()),
  ('Pack Office plante - Compta',    'Erreur 0x80070005 au lancement.',                      3,3,3,3,1,2,1,0,NOW(),NOW()),
  ('Demande accès dossier Compta',   'Ajout au partage \\\\srv-files-01\\Compta',             6,2,2,2,2,4,1,0,NOW(),NOW()),
  ('Écran scintille - PC-KINE-05',   'Après changement batterie.',                           4,3,3,3,1,1,2,0,NOW(),NOW());
SQL

echo "✅ Données de démo injectées :"
${DB_EXEC} -e "SELECT COUNT(*) AS ordinateurs FROM glpi_computers; SELECT COUNT(*) AS tickets FROM glpi_tickets;"
