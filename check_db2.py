import sqlite3
import os

paths = [
    'C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend/data/rwa_data.db',
    'C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend/rwa_data.db',
    'C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend/database.sqlite',
]

for p in paths:
    if os.path.exists(p):
        print("FOUND:", p)
        conn = sqlite3.connect(p)
        try:
            print(conn.execute("SELECT date_octroi, date_echeance FROM expositions WHERE id='EXP-2026-0153'").fetchone())
        except Exception as e:
            print("Error:", e)
