"""Utilitaires de chemins pour les executions source et packagées."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import sys


APP_FOLDER_NAME = "Risk management"
PACKAGED_ENV_VAR = "RWA_PACKAGED"


def backend_source_root() -> Path:
    """Retourne la racine du backend dans le dépôt source ou le package embarqué."""

    return Path(__file__).resolve().parents[2]


def backend_resource_root() -> Path:
    """Retourne la racine des ressources embarquées ou du dépôt source."""

    bundle_root = getattr(sys, "_MEIPASS", None)
    if bundle_root:
        return Path(bundle_root)
    return backend_source_root()


def is_packaged_runtime() -> bool:
    """Indique si le backend s'exécute depuis un package desktop embarqué."""

    return getattr(sys, "frozen", False) or os.environ.get(PACKAGED_ENV_VAR) == "1"


def app_data_root() -> Path:
    """Retourne le dossier d'écriture des données utilisateur."""

    if is_packaged_runtime():
        local_app_data = os.environ.get("LOCALAPPDATA")
        if local_app_data:
            return Path(local_app_data) / APP_FOLDER_NAME
        return Path.home() / "AppData" / "Local" / APP_FOLDER_NAME
    return backend_source_root() / "data"


def exports_dir() -> Path:
    return app_data_root() / "exports"


def backups_dir() -> Path:
    return app_data_root() / "backups"


def logs_dir() -> Path:
    return app_data_root() / "logs"


def resource_path(*parts: str) -> Path:
    """Construit un chemin vers une ressource embarquée."""

    return backend_resource_root().joinpath(*parts)


def seed_data_path(filename: str) -> Path:
    """Retourne le chemin d'une donnée de démarrage fournie avec le package."""

    return resource_path("data", filename)


def ensure_seed_data_file(filename: str) -> Path:
    """Copie une donnée packagée vers AppData si elle n'existe pas encore."""

    target_path = app_data_root() / filename
    if target_path.exists():
        return target_path

    source_path = seed_data_path(filename)
    if source_path.exists():
        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, target_path)
    return target_path


def default_excel_source_path() -> Path:
    return ensure_seed_data_file("modele_import_rwa.xlsx")
