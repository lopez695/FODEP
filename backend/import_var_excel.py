import sqlite3
import pandas as pd
from pathlib import Path

DB_PATH = Path(r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\backend\data\rwa_data.db")
EXCEL_PATH = Path(r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\Modele_Import_Risque_Marche.xlsx")

def import_excel_to_db():
    if not DB_PATH.exists():
        print("Erreur: La base de données rwa_data.db n'existe pas.")
        return
        
    if not EXCEL_PATH.exists():
        print(f"Erreur: Le fichier Excel {EXCEL_PATH} est introuvable.")
        return
        
    print(f"Lecture du fichier {EXCEL_PATH}...")
    
    try:
        # Lire Obligations
        df_bonds = pd.read_excel(EXCEL_PATH, sheet_name="Obligations")
        df_bonds = df_bonds.rename(columns={
            "ID Titre": "isin",
            "Emetteur": "emetteur",
            "Devise": "devise",
            "Valeur nominale unitaire": "valeur_nominale",
            "Coupon (%)": "taux_coupon_pct",
            "Fréquence de paiement des intérêts": "frequence_coupon",
            "Date d'émission": "date_emission",
            "Date d'échéance": "date_echeance",
            "quantités": "quantite",
            "Prix d'émission": "prix_marche_pct" # Utiliser le prix d'émission comme proxy si besoin, ou ajouter une colonne prix
        })
        
        # Lire Historique Prix Obligations
        df_hist_bonds = pd.read_excel(EXCEL_PATH, sheet_name="Historique Prix Obligations")
        df_hist_bonds = df_hist_bonds.rename(columns={
            "Date": "date",
            "ID Titre": "isin",
            "Prix de marché": "prix_marche_pct"
        })
        
        # Lire Actions
        df_equities = pd.read_excel(EXCEL_PATH, sheet_name="Actions")
        df_equities = df_equities.rename(columns={
            "ID Instrument": "ticker",
            "Émetteur / Société": "libelle",
            "Secteur": "secteur",
            "Quantité": "quantite",
            "Cours actuel": "cours_actuel"
        })
        
        # Lire Historique Cours Actions
        df_hist_equities = pd.read_excel(EXCEL_PATH, sheet_name="Historique Cours Actions")
        df_hist_equities = df_hist_equities.rename(columns={
            "Date": "date",
            "ID Instrument": "ticker",
            "Cours de clôture": "cours_cloture"
        })
        
        print("Connexion à la base de données SQLite...")
        with sqlite3.connect(DB_PATH) as conn:
            # Vider les tables existantes
            cursor = conn.cursor()
            cursor.execute("DELETE FROM positions_obligations")
            cursor.execute("DELETE FROM historique_prix_obligations")
            cursor.execute("DELETE FROM positions_actions")
            cursor.execute("DELETE FROM historique_cours_actions")
            
            # Insérer les nouvelles données
            if not df_bonds.empty:
                cols = ["isin", "emetteur", "devise", "valeur_nominale", "taux_coupon_pct", "frequence_coupon", "date_emission", "date_echeance", "quantite", "prix_marche_pct"]
                df_bonds_sub = df_bonds[[c for c in cols if c in df_bonds.columns]]
                df_bonds_sub.to_sql("positions_obligations", conn, if_exists="append", index=False)
                df_bonds_sub.to_csv(DB_PATH.parent / "positions_obligations.csv", index=False)
                
            if not df_hist_bonds.empty:
                df_hist_bonds.to_sql("historique_prix_obligations", conn, if_exists="append", index=False)
                df_hist_bonds.to_csv(DB_PATH.parent / "historique_prix_obligations.csv", index=False)
                
            if not df_equities.empty:
                # Le cours actuel sert de valorisation de repli quand aucun
                # historique de cours n'est importé (mode réglementaire).
                colonnes_table = [ligne[1] for ligne in cursor.execute("PRAGMA table_info(positions_actions)")]
                if colonnes_table and "cours_actuel" not in colonnes_table:
                    cursor.execute("ALTER TABLE positions_actions ADD COLUMN cours_actuel TEXT")
                cols = ["ticker", "libelle", "secteur", "quantite", "cours_actuel"]
                df_equities_sub = df_equities[[c for c in cols if c in df_equities.columns]]
                df_equities_sub.to_sql("positions_actions", conn, if_exists="append", index=False)
                df_equities_sub.to_csv(DB_PATH.parent / "positions_actions.csv", index=False)
                
            if not df_hist_equities.empty:
                df_hist_equities.to_sql("historique_cours_actions", conn, if_exists="append", index=False)
                df_hist_equities.to_csv(DB_PATH.parent / "historique_cours_actions.csv", index=False)
                
        print("Succès ! Les données et historiques ont été importés dans la base locale (rwa_data.db).")
        print("La Value at Risk est désormais opérationnelle avec les vraies données.")
        
    except Exception as e:
        print(f"Erreur lors de l'importation: {e}")

if __name__ == "__main__":
    import_excel_to_db()
