# Image unique : API + application web, pour un hebergeur qui n'expose qu'un
# seul service (Render, Fly, Railway...).
#
# L'application web est construite ICI, pendant la mise en ligne. Le resultat
# pese une cinquantaine de mega-octets, dont 32 pour le moteur graphique : le
# versionner alourdirait le depot a chaque deploiement. L'hebergeur le
# reconstruit a partir du code source, qui lui est leger.

# --- Etape 1 : construction de l'application Flutter Web -------------------
FROM ghcr.io/cirruslabs/flutter:3.41.3 AS application-web

WORKDIR /src

# Les dependances sont resolues avant de copier le code : tant que pubspec ne
# change pas, cette couche est reutilisee et la construction repart plus vite.
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get

COPY frontend/ ./

# Le moteur graphique est embarque dans l'image, jamais charge depuis un
# service exterieur : aucune requete ne sort vers un tiers a l'execution.
#
# « --pwa-strategy=none » : aucun service worker. Un outil interne derriere
# authentification n'a pas besoin du mode hors-ligne, et le service worker
# « offline-first » de Flutter ressert son propre cache jusqu'a fermeture de
# TOUS les onglets — d'ou des postes bloques sur une version perimee malgre un
# serveur a jour. Sans lui, le navigateur recharge le code frais a chaque
# visite (les fichiers sont deja servis « no-store » par l'API).
RUN flutter build web --release --no-wasm-dry-run --pwa-strategy=none

# --- Etape 2 : API Python qui sert aussi l'application ---------------------
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUTF8=1 \
    RWA_PACKAGED=1 \
    RWA_WEB_DIR=/app/web

WORKDIR /app

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY backend/app ./app
COPY backend/database ./database
COPY backend/run_server.py ./
COPY backend/data ./data

# Application web servie par l'API sur la meme adresse : une seule origine,
# donc aucune requete croisee et un cookie de session de premiere partie.
COPY --from=application-web /src/build/web ./web

RUN useradd --create-home --uid 10001 rwa \
    && mkdir -p /donnees \
    && chown -R rwa:rwa /app /donnees
USER rwa

ENV LOCALAPPDATA=/donnees

# L'hebergeur impose le port par la variable PORT. Forme shell obligatoire
# pour que la variable soit interpretee.
CMD python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1 --proxy-headers --forwarded-allow-ips '*'
