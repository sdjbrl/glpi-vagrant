# GLPI sur Railway — wrapper de l'image diouxx/glpi
# - Railway route HTTPS public → port interne défini par $PORT (défaut 80)
# - Apache de l'image écoute sur 80 ; on patche sa conf si PORT diffère
# - Toutes les variables sensibles (DB) sont injectées par Railway

FROM diouxx/glpi:latest

# iproute2 pour diagnostiquer les ports en écoute (ss)
RUN apt-get update --allow-releaseinfo-change || true \
 && apt-get install -y --no-install-recommends iproute2 \
 && rm -rf /var/lib/apt/lists/* || true

COPY railway/railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# ServerName global pour supprimer le warning AH00558
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
 && a2enconf servername

ENV PORT=80
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
