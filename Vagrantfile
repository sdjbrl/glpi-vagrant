# Vagrantfile — Lab GLPI Docker (Saïd AHMED MOUSSA / sdjbrl)
# Wrapper Vagrant autour de la stack docker-compose (GLPI + MariaDB + phpMyAdmin)
#
# Inspiration initiale : https://github.com/Mediaschool-IRIS-BTS-SISR-2025/Serveur_GLPI_Louka
# Refactor / corrections / extensions :
#   - Bug d'indentation YAML labels Traefik corrigé
#   - Stack autonome (sans Traefik en dev) + variante prod (docker-compose.prod.yml)
#   - Healthchecks MariaDB & dépendances service_healthy
#   - Conf PHP & MariaDB tunées pour GLPI 10
#   - Scripts backup / restore / update / seed-demo-data
#   - Docs complètes (INSTALL / USAGE / CONFIG / ARCHITECTURE)
#   - Données démo contextualisées Kiné@dom (alternance)
# Cible production : glpi.saiddev.fr (Traefik + Let's Encrypt)

Vagrant.configure("2") do |config|
  config.vm.box      = "bento/debian-12"
  config.vm.hostname = "glpi-srv"

  # Accès web depuis l'hôte
  config.vm.network "forwarded_port", guest: 80,   host: 8080, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8081, host: 8081, host_ip: "127.0.0.1"
  config.vm.network "private_network", ip: "192.168.56.30"

  # Le dossier projet est monté dans /vagrant
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "glpi-srv"
    vb.memory = 2048
    vb.cpus   = 2
    vb.customize ["modifyvm", :id, "--audio-driver", "none"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end

  config.vm.provision "base",     type: "shell", path: "provision/01-base.sh"
  config.vm.provision "docker",   type: "shell", path: "provision/02-docker.sh"
  config.vm.provision "compose",  type: "shell", path: "provision/03-compose-up.sh"
  config.vm.provision "validate", type: "shell", path: "provision/99-validate.sh"

  config.vm.post_up_message = <<~MSG

    ╔══════════════════════════════════════════════════════════════╗
    ║  ✅ Stack GLPI prête                                         ║
    ║                                                              ║
    ║  🌐 GLPI         : http://localhost:8080                     ║
    ║  🛠 phpMyAdmin   : http://localhost:8081                     ║
    ║                                                              ║
    ║  👤 Comptes GLPI par défaut (à changer au 1er login !) :     ║
    ║     glpi      / glpi       (super-admin)                     ║
    ║     tech      / tech       (technicien)                      ║
    ║     normal    / normal     (utilisateur)                     ║
    ║     post-only / postonly   (création tickets)                ║
    ║                                                              ║
    ║  💾 Données persistées dans ./data/ (gitignored)             ║
    ║  🔧 SSH          : vagrant ssh                               ║
    ║  📜 Logs         : docker compose logs -f                    ║
    ╚══════════════════════════════════════════════════════════════╝

  MSG
end
