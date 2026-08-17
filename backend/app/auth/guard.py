"""Garde central : refus par defaut, autorisation par exception.

Le choix structurant est ici. Proteger cent routes une par une reviendrait a
parier qu'aucun oubli ne se produira, ni aujourd'hui ni sur la prochaine route
ecrite. La regle est donc inversee : tout appel exige un jeton valide, et toute
methode qui modifie l'etat exige le role « edition ». Une route ajoutee demain
est protegee sans que personne n'ait a y penser.
"""

from __future__ import annotations

from starlette.concurrency import run_in_threadpool
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.auth.espaces import preparer_espace
from app.auth.security import (
    InvalidTokenError,
    TYPE_ACCES,
    decode_token,
)
from database.connection import restaurer_espace, utiliser_espace

# Le module est importe, pas l'objet : la configuration est relue a chaque
# requete. Capturer `settings` au chargement figerait l'etat du garde pour
# toute la duree du processus, y compris apres un rechargement de la
# configuration.
from app.core import config

# Chemins accessibles sans jeton : la connexion elle-meme, le renouvellement
# (qui porte sa preuve dans le cookie) et la sonde de sante du conteneur.
CHEMINS_PUBLICS: frozenset[str] = frozenset(
    {
        "/",
        "/sante",
        "/auth/login",
        "/auth/refresh",
        "/auth/logout",
    }
)

# Fichiers de l'application web, servis par l'API lorsqu'elle l'embarque.
#
# Ils DOIVENT rester accessibles sans jeton : c'est cette application qui
# affiche l'ecran de connexion. Exiger un jeton pour la telecharger reviendrait
# a demander la cle de la porte a quelqu'un qui n'est pas encore entre. Aucune
# donnee prudentielle ne s'y trouve : ce sont du code et des images, les
# chiffres n'arrivent que par les appels d'API, eux proteges.
PREFIXES_APPLICATION_WEB: tuple[str, ...] = (
    "/assets/",
    "/canvaskit/",
    "/icons/",
)

FICHIERS_APPLICATION_WEB: frozenset[str] = frozenset(
    {
        "/index.html",
        "/main.dart.js",
        "/flutter.js",
        "/flutter_bootstrap.js",
        "/flutter_service_worker.js",
        "/version.json",
        "/manifest.json",
        "/favicon.png",
    }
)


def _est_fichier_application(chemin: str) -> bool:
    """Vrai pour un fichier de l'application web servi a la racine."""

    if chemin in FICHIERS_APPLICATION_WEB:
        return True
    return chemin.startswith(PREFIXES_APPLICATION_WEB)

# Methodes qui ne modifient rien.
METHODES_LECTURE: frozenset[str] = frozenset({"GET", "HEAD", "OPTIONS"})


def _refus(status_code: int, message: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"detail": message})


class AuthGuardMiddleware(BaseHTTPMiddleware):
    """Applique l'authentification et le controle de role a chaque requete."""

    async def dispatch(self, request: Request, call_next):
        if not config.settings.auth_enabled:
            return await call_next(request)

        # Le pre-vol CORS ne porte jamais d'en-tete d'autorisation : le
        # bloquer empecherait le navigateur d'envoyer la vraie requete.
        if request.method == "OPTIONS":
            return await call_next(request)

        chemin = request.url.path.rstrip("/") or "/"
        if chemin in CHEMINS_PUBLICS:
            return await call_next(request)

        # Les fichiers de l'application web restent libres, mais uniquement
        # s'ils ne sont pas demandes comme un appel d'API : un chemin prefixe
        # par « /api » vise toujours des donnees, jamais un fichier.
        if not request.scope.get("rwa_appel_api") and _est_fichier_application(
            chemin
        ):
            return await call_next(request)

        entete = request.headers.get("Authorization", "")
        schema, _, jeton = entete.partition(" ")
        if schema.lower() != "bearer" or not jeton.strip():
            return _refus(401, "Authentification requise.")

        try:
            charge = decode_token(jeton.strip(), expected_type=TYPE_ACCES)
        except InvalidTokenError as exc:
            return _refus(401, str(exc))

        role = str(charge.get("role") or "")
        # Chaque compte ecrit dans SON espace, et nulle part ailleurs : importer
        # un fichier ou corriger une exposition n'affecte donc personne
        # d'autre. Interdire l'ecriture a la consultation n'aurait plus rien
        # protege -- cela aurait seulement empeche quelqu'un de travailler sur
        # ses propres donnees.
        #
        # Ce qui reste reserve au role « edition » est la gestion de l'equipe,
        # verifiee explicitement par les routes concernees : elle porte sur les
        # comptes, qui sont communs, et non sur un espace de travail.

        identifiant = str(charge.get("sub") or "")
        request.state.utilisateur = {
            "identifiant": identifiant,
            "id": charge.get("uid"),
            "role": role,
        }

        # A partir d'ici, toute lecture ou ecriture de donnees metier vise
        # l'espace de ce compte, et lui seul. Les routes d'authentification
        # n'en dependent pas : elles rebasculent sur la base commune.
        espace = await run_in_threadpool(preparer_espace, identifiant)
        jeton_espace = utiliser_espace(espace)
        try:
            return await call_next(request)
        finally:
            restaurer_espace(jeton_espace)
