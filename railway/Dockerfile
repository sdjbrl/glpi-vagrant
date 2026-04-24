# GLPI sur Railway — wrapper de l'image diouxx/glpi
# - Railway route HTTPS public → port interne défini par $PORT (défaut 80)
# - Apache de l'image écoute sur 80 ; on patche sa conf si PORT diffère
# - Toutes les variables sensibles (DB) sont injectées par Railway

FROM diouxx/glpi:latest

# Pas de RUN apt-get : l'entrypoint n'utilise que sed (déjà présent)
# Évite les erreurs de clé GPG sury.org du repo PHP de l'image upstream

COPY railway/railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV PORT=80
EXPOSE 80

# Pas de CMD : /opt/glpi-start.sh (appelé par notre entrypoint) gère Apache + init GLPI
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
