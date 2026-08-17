# Backend FastAPI de l'outil RWA.
FROM python:3.12-slim

# Les dependances scientifiques (numpy, scipy, pandas) sont livrees en roues
# precompilees : aucune chaine de compilation n'est necessaire dans l'image.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUTF8=1 \
    RWA_PACKAGED=1

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY database ./database
COPY run_server.py ./

# Donnees de demarrage. L'application les copie vers le volume au premier
# lancement si celui-ci est vide, puis ne les ecrase plus jamais : les saisies
# de l'utilisateur ne sont pas effacees par une mise a jour d'image.
COPY data ./data

# L'API tourne sous un compte sans privileges : une faille applicative ne doit
# pas donner les droits d'administration du conteneur.
RUN useradd --create-home --uid 10001 rwa \
    && mkdir -p /donnees \
    && chown -R rwa:rwa /app /donnees
USER rwa

# Repertoire de travail des donnees (base SQLite, sauvegardes, exports, logs).
# Monte comme volume dans docker-compose : les donnees survivent a l'image.
ENV LOCALAPPDATA=/donnees
VOLUME ["/donnees"]

EXPOSE 8000

# Un seul worker, deliberement. SQLite n'admet qu'un redacteur, et les deux
# traitements de demarrage (recalcul reglementaire, realignement des impayes)
# s'executeraient en concurrence sur la meme base avec plusieurs workers.
# Monter en charge passerait par PostgreSQL, pas par des workers supplementaires.
CMD ["python", "-m", "uvicorn", "app.main:app", \
     "--host", "0.0.0.0", "--port", "8000", "--workers", "1", \
     "--proxy-headers", "--forwarded-allow-ips", "*"]
