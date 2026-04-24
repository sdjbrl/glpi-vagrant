# GLPI sur Railway — wrapper de l'image diouxx/glpi
# - Railway route HTTPS public → port interne défini par $PORT (défaut 80)
# - Apache de l'image écoute sur 80 ; on patche sa conf si PORT diffère
# - Toutes les variables sensibles (DB) sont injectées par Railway

FROM diouxx/glpi:latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends gettext-base curl \
 && rm -rf /var/lib/apt/lists/*

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV PORT=80
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["apache2-foreground"]
