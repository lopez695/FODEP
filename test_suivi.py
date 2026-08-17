import sys
sys.path.append('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend')
from app.core.runtime_paths import ensure_seed_data_file
from database.connection import database_manager
from app.expositions.suivi_service import get_suivi

database_manager.initialize()
print(get_suivi("EXP-2026-0153"))
