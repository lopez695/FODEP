"""Lanceur du backend pour les builds desktop packagés."""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
os.chdir(BACKEND_DIR)

import uvicorn

from app.core.runtime_paths import logs_dir
from app.main import app

# Volontairement sans "tests" : editer un test ne doit pas redemarrer l'API
# sous les pieds du client, chaque redemarrage coupant les connexions en cours.
RELOAD_DIRS = [
    BACKEND_DIR / "app",
    BACKEND_DIR / "database",
    BACKEND_DIR / "scripts",
]
RELOAD_EXCLUDES = [
    ".venv/*",
    "__pycache__/*",
    ".pytest_cache/*",
    "data/*",
    "*.pyc",
]


def _configure_logging() -> None:
    log_directory = logs_dir()
    log_directory.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(
                Path(log_directory) / "backend.log",
                encoding="utf-8",
            )
        ],
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Lance le backend FastAPI.")
    parser.add_argument(
        "--reload",
        action="store_true",
        help="Active le rechargement automatique en developpement.",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("RWA_API_HOST", "127.0.0.1"),
        help="Adresse d'ecoute du serveur.",
    )
    parser.add_argument(
        "--port",
        type=int,
        # 8001 est le port qu'attend le client desktop lorsque RWA_API_PORT
        # n'est pas defini (voir _resolveDefaultApiBaseUrl cote Flutter) et
        # celui que documente le README. Un defaut a 8000 faisait demarrer le
        # backend la ou l'application n'allait jamais le chercher.
        default=int(os.environ.get("RWA_API_PORT", "8001")),
        help="Port d'ecoute du serveur.",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    _configure_logging()
    log_level = os.environ.get("RWA_API_LOG_LEVEL", "warning")
    uvicorn.run(
        "app.main:app" if args.reload else app,
        host=args.host,
        port=args.port,
        log_level=log_level,
        access_log=False,
        reload=args.reload,
        reload_dirs=[str(path) for path in RELOAD_DIRS if path.exists()] if args.reload else None,
        reload_excludes=RELOAD_EXCLUDES if args.reload else None,
        app_dir=str(BACKEND_DIR),
    )


if __name__ == "__main__":
    main()
