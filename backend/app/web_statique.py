"""Service de l'application Flutter Web par l'API elle-meme.

Sur un hebergeur qui n'expose qu'un seul service (Render, Fly, Railway...), il
n'y a ni proxy inverse ni conteneur separe pour les fichiers statiques :
l'application et l'API doivent partager le meme programme, donc la meme
origine. C'est d'ailleurs preferable — aucune requete d'origine croisee, et le
cookie de session reste strictement de premiere partie.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

logger = logging.getLogger(__name__)

# Fichiers dont le nom n'est PAS versionne par Flutter : les mettre en cache
# ferait servir l'ancienne application apres chaque mise en ligne.
_JAMAIS_EN_CACHE = {
    "index.html",
    "main.dart.js",
    "flutter_bootstrap.js",
    "flutter_service_worker.js",
    "version.json",
    "manifest.json",
}


def repertoire_web() -> Path | None:
    """Repertoire du build Flutter Web, s'il est present."""

    configure = os.getenv("RWA_WEB_DIR", "").strip()
    candidats = [Path(configure)] if configure else []

    # Emplacements relatifs au code. Le nombre de niveaux au-dessus varie selon
    # le montage (image unique, depot source) : les chemins hors de
    # l'arborescence sont simplement ignores plutot que de faire echouer le
    # demarrage de l'API.
    racine_module = Path(__file__).resolve()
    for niveaux, sous_chemin in ((2, ("web",)), (3, ("frontend", "build", "web"))):
        try:
            base = racine_module.parents[niveaux]
        except IndexError:
            continue
        candidats.append(base.joinpath(*sous_chemin))

    for candidat in candidats:
        if (candidat / "index.html").exists():
            return candidat
    return None


class _StatiqueSansCacheApplicatif(StaticFiles):
    """Sert les fichiers, en interdisant le cache du code de l'application."""

    def file_response(self, *args, **kwargs) -> Response:  # type: ignore[override]
        reponse = super().file_response(*args, **kwargs)
        nom = Path(getattr(reponse, "path", "")).name
        if nom in _JAMAIS_EN_CACHE:
            reponse.headers["Cache-Control"] = "no-store, must-revalidate"
        else:
            reponse.headers["Cache-Control"] = "public, max-age=604800"
        return reponse


def monter_application_web(app: FastAPI) -> bool:
    """Monte l'application web sur « / ». Retourne False si elle est absente."""

    racine = repertoire_web()
    if racine is None:
        logger.info(
            "Aucun build Flutter Web trouve : l'API demarre seule "
            "(mode poste de travail ou developpement)."
        )
        return False

    index = racine / "index.html"

    # Monte en dernier, sur « / » : les routes de l'API sont declarees avant et
    # gardent donc la priorite. Seuls les chemins inconnus arrivent ici.
    app.mount(
        "/",
        _StatiqueSansCacheApplicatif(directory=str(racine), html=True),
        name="application-web",
    )

    @app.exception_handler(404)
    async def _retour_application(request, exc):  # type: ignore[unused-ignore]
        """Toute adresse inconnue retombe sur l'application, pas sur une erreur."""

        chemin = request.url.path
        # Une API introuvable doit rester une erreur d'API : renvoyer la page
        # d'accueil masquerait un appel casse derriere un ecran normal.
        if (
            request.scope.get("rwa_appel_api")
            or chemin.startswith("/api")
            or chemin.startswith("/auth")
        ):
            return Response(status_code=404)
        reponse = FileResponse(index)
        reponse.headers["Cache-Control"] = "no-store, must-revalidate"
        return reponse

    logger.info("Application web servie depuis %s", racine)
    return True
