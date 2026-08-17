import sqlite3
import os

DB_PATH = r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\backend\data\rwa_data.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # positions_obligations
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS positions_obligations (
        isin TEXT,
        emetteur TEXT,
        devise TEXT,
        valeur_nominale TEXT,
        taux_coupon_pct TEXT,
        frequence_coupon TEXT,
        date_emission TEXT,
        date_echeance TEXT,
        quantite TEXT,
        prix_marche_pct TEXT
    )
    """)

    # historique_prix_obligations
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS historique_prix_obligations (
        date TEXT,
        isin TEXT,
        prix_marche_pct TEXT
    )
    """)
    
    # historique_taux
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS historique_taux (
        date TEXT,
        tenor_1m TEXT,
        tenor_3m TEXT,
        tenor_6m TEXT,
        tenor_1y TEXT,
        tenor_2y TEXT,
        tenor_5y TEXT,
        tenor_10y TEXT
    )
    """)

    # positions_actions
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS positions_actions (
        ticker TEXT,
        libelle TEXT,
        secteur TEXT,
        quantite TEXT,
        cours_actuel TEXT
    )
    """)

    # Migration des bases existantes : le cours actuel permet de valoriser
    # le portefeuille actions sans historique (mode réglementaire).
    colonnes = [ligne[1] for ligne in cursor.execute("PRAGMA table_info(positions_actions)")]
    if "cours_actuel" not in colonnes:
        cursor.execute("ALTER TABLE positions_actions ADD COLUMN cours_actuel TEXT")

    # historique_cours_actions
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS historique_cours_actions (
        date TEXT,
        ticker TEXT,
        cours_cloture TEXT
    )
    """)

    conn.commit()
    conn.close()
    print("Tables created successfully.")

if __name__ == "__main__":
    init_db()
