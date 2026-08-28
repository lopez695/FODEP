"""Point d'entree principal de l'API FastAPI."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.auth.bootstrap import creer_comptes_initiaux
from app.auth.guard import AuthGuardMiddleware
from app.auth.routes import router as auth_router
from app.auth.security import AuthConfigurationError, resolve_secret
from app.core.config import settings
from app.web_statique import monter_application_web
from app.crm.routes import router as crm_router
from app.dashboard.routes import router as dashboard_router
from app.expositions.routes import router as expositions_router
from app.hors_bilan.routes import router as hors_bilan_router
from app.groupes_clients.routes import router as groupes_clients_router
from app.market.routes import router as market_router
from app.participations.routes import router as participations_router
from app.rapports.routes import router as rapports_router
from app.referentiels.routes import router as referentiels_router
from app.risque_operationnel.routes import router as risque_operationnel_router
from app.icaap.routes import router as icaap_router
from app.rwa_credit.routes import router as rwa_credit_router
from app.var_marche.routes import router as var_marche_router
from database.connection import database_manager
from app.expositions.suivi_service import schedule_startup_delinquency_refresh
from database.services.exposure_sync_service import exposure_sync_service

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gère le démarrage et l'arrêt de l'application."""
    # Startup
    database_manager.initialize()
    try:
        exposure_sync_service.schedule_reference_fields_backfill()
    except Exception:
        logger.exception(
            "La planification du backfill des dates/reference Expositions a échoué."
        )
    try:
        # Un seul fil enchaîne les deux passes qui réécrivent les expositions :
        # le recalcul réglementaire (si les règles ont changé depuis le dernier
        # démarrage), puis le réalignement du suivi (jours d'impayés qui
        # avancent avec le temps, encours amorti par les versements).
        schedule_startup_delinquency_refresh()
    except Exception:
        logger.exception(
            "La planification du réalignement des expositions a échoué."
        )
    if settings.auth_enabled:
        try:
            # Hébergeur sans console : les comptes initiaux viennent de
            # l'environnement. Un compte déjà présent n'est jamais modifié.
            creer_comptes_initiaux()
        except Exception:
            logger.exception("La création des comptes initiaux a échoué.")
    yield
    # Shutdown
    logger.info("Application en cours d'arrêt...")


class PrefixeApiMiddleware:
    """Accepte les appels prefixes par « /api » comme s'ils ne l'etaient pas.

    Le poste de travail appelle « /dashboard », le navigateur « /api/dashboard »
    (l'API et l'application partagent alors une seule adresse). Plutot que de
    declarer chaque route deux fois, le prefixe est retire ici, avant le
    routage. Les deux clients cohabitent sans duplication.
    """

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope.get("type") == "http":
            chemin = scope.get("path", "")
            if chemin == "/api" or chemin.startswith("/api/"):
                scope = dict(scope)
                nouveau_chemin = chemin[len("/api") :] or "/"
                scope["path"] = nouveau_chemin
                if scope.get("raw_path"):
                    scope["raw_path"] = nouveau_chemin.encode("utf-8")
                # Trace conservee : une adresse d'API inconnue doit rester une
                # erreur, et non retomber sur la page de l'application.
                scope["rwa_appel_api"] = True
        await self.app(scope, receive, send)


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)

# Un demarrage avec authentification active mais sans secret exploitable doit
# echouer bruyamment ici, et non servir des jetons signes avec une valeur vide.
if settings.auth_enabled:
    try:
        resolve_secret()
    except AuthConfigurationError as exc:
        raise RuntimeError(f"Configuration d'authentification invalide : {exc}") from exc
    logger.info("Authentification activee : jeton requis sur toutes les routes.")
else:
    logger.warning(
        "Authentification desactivee (RWA_AUTH_ENABLED absent ou a 0). "
        "N'exposez jamais cette API en dehors de la boucle locale."
    )

# L'ordre compte : le dernier middleware ajoute est le plus externe. CORS doit
# donc etre ajoute APRES le garde pour traiter le pre-vol du navigateur avant
# toute verification de jeton.
app.add_middleware(AuthGuardMiddleware)

_origines_configurees = [
    origine.strip()
    for origine in settings.allowed_origins.split(",")
    if origine.strip()
]
app.add_middleware(
    CORSMiddleware,
    # Liste explicite, jamais de joker : avec des identifiants en jeu, « * »
    # laisserait n'importe quelle page appeler l'API au nom de l'utilisateur.
    allow_origins=_origines_configurees
    or ["http://localhost", "http://127.0.0.1"],
    allow_origin_regex=None
    if _origines_configurees
    else r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
    # Necessaire pour que le navigateur accepte de poser et de renvoyer le
    # cookie de renouvellement lorsque l'API est sur une autre origine.
    allow_credentials=True,
)

app.include_router(auth_router)
app.include_router(dashboard_router)
app.include_router(expositions_router)
app.include_router(hors_bilan_router)
app.include_router(crm_router)
app.include_router(referentiels_router)
app.include_router(participations_router)
app.include_router(groupes_clients_router)
app.include_router(rapports_router)
app.include_router(market_router)
app.include_router(risque_operationnel_router)
app.include_router(rwa_credit_router)
app.include_router(var_marche_router)
app.include_router(icaap_router)


@app.get("/sante")
def sante() -> dict[str, str]:
    """Sonde de sante, joignable sans jeton."""

    return {"message": "Risk management API is running"}


# Compatibilite : la racine reste une sonde tant qu'aucune application web
# n'est embarquee. Des qu'elle l'est, « / » sert la page d'accueil.
if not monter_application_web(app):

    @app.get("/")
    def root() -> dict[str, str]:
        """Expose un message simple de sante de l'API."""

        return {"message": "Risk management API is running"}


# Ajoute en dernier, donc le plus externe : le prefixe doit etre retire avant
# le CORS, le garde d'authentification et le routage.
app.add_middleware(PrefixeApiMiddleware)
