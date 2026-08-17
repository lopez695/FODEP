# Application Flutter Web servie par Nginx.
#
# Le build Flutter est fait EN AMONT sur le poste de developpement
# (`flutter build web --release`), pas dans l'image : embarquer le SDK Flutter
# ferait une image de plusieurs gigaoctets pour un resultat identique.
# Le repertoire build/web doit donc exister avant `docker compose build`.
FROM nginx:1.27-alpine

# Configuration servie : routage de l'application a page unique et en-tetes de
# securite. Voir frontend/nginx.conf.
COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY build/web /usr/share/nginx/html

EXPOSE 80
