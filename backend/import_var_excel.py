"""Charge le classeur d'historique VaR marche dans la base locale.

Meme lecture que `POST /market/upload-var-history` : deux feuilles au format
long (« Obligations », « Actions »), une ligne = un titre a une date. Les
caracteristiques statiques donnent la position (premiere occurrence de
l'identifiant), les couples (Date, Prix) donnent l'historique. Les deux
feuilles « Historique ... » de l'ancien format a quatre feuilles ont disparu
du modele : leur contenu vit desormais dans la feuille du titre.
"""

import sqlite3
import sys
from pathlib import Path

import pandas as pd

RACINE_BACKEND = Path(__file__).resolve().parent
sys.path.insert(0, str(RACINE_BACKEND))

from app.var_marche import portefeuille_data  # noqa: E402

DB_PATH = RACINE_BACKEND / "data" / "rwa_data.db"
EXCEL_PATH = RACINE_BACKEND.parent / "frontend" / "Modele_Import_Risque_Marche.xlsx"


def _separer_positions_et_historique(df, *, id_col, positions_cols, date_col, prix_col, hist_cols):
    """Scinde une feuille au format long en (positions, historique)."""

    presentes = [c for c in positions_cols if c in df.columns]
    if id_col in df.columns:
        positions = df.drop_duplicates(subset=[id_col])[presentes].reset_index(drop=True)
    else:
        positions = pd.DataFrame(columns=presentes)

    if date_col in df.columns and prix_col in df.columns:
        historique = df.dropna(subset=[date_col, prix_col])[hist_cols].reset_index(drop=True)
    else:
        historique = pd.DataFrame(columns=hist_cols)
    return positions, historique


def import_excel_to_db():
    if not DB_PATH.exists():
        print("Erreur: La base de données rwa_data.db n'existe pas.")
        return

    if not EXCEL_PATH.exists():
        print(f"Erreur: Le fichier Excel {EXCEL_PATH} est introuvable.")
        return

    print(f"Lecture du fichier {EXCEL_PATH}...")

    try:
        # Lire Obligations (positions + historique dans le même onglet)
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
            "Date": "date",
            "Prix de marché (%)": "prix_marche_pct",
        })
        if "frequence_coupon" in df_bonds.columns:
            df_bonds["frequence_coupon"] = df_bonds["frequence_coupon"].apply(
                lambda v: portefeuille_data.normaliser_frequence_coupon(
                    "" if pd.isna(v) else str(v)
                )
            )
        df_bonds_sub, df_hist_bonds = _separer_positions_et_historique(
            df_bonds,
            id_col="isin",
            positions_cols=[
                "isin", "emetteur", "devise", "valeur_nominale", "taux_coupon_pct",
                "frequence_coupon", "date_emission", "date_echeance", "quantite",
            ],
            date_col="date",
            prix_col="prix_marche_pct",
            hist_cols=["date", "isin", "prix_marche_pct"],
        )

        # Lire Actions (positions + historique dans le même onglet)
        df_equities = pd.read_excel(EXCEL_PATH, sheet_name="Actions")
        df_equities = df_equities.rename(columns={
            "ID Instrument": "ticker",
            "Émetteur / Société": "libelle",
            "Secteur": "secteur",
            "Quantité": "quantite",
            "Date": "date",
            "Cours de clôture": "cours_cloture",
        })
        df_equities_sub, df_hist_equities = _separer_positions_et_historique(
            df_equities,
            id_col="ticker",
            positions_cols=["ticker", "libelle", "secteur", "quantite"],
            date_col="date",
            prix_col="cours_cloture",
            hist_cols=["date", "ticker", "cours_cloture"],
        )

        print("Connexion à la base de données SQLite...")
        with sqlite3.connect(DB_PATH) as conn:
            # Vider les tables existantes
            cursor = conn.cursor()
            cursor.execute("DELETE FROM positions_obligations")
            cursor.execute("DELETE FROM historique_prix_obligations")
            cursor.execute("DELETE FROM positions_actions")
            cursor.execute("DELETE FROM historique_cours_actions")

            # Insérer les nouvelles données
            if not df_bonds_sub.empty:
                df_bonds_sub.to_sql("positions_obligations", conn, if_exists="append", index=False)
                df_bonds_sub.to_csv(DB_PATH.parent / "positions_obligations.csv", index=False)

            if not df_hist_bonds.empty:
                df_hist_bonds.to_sql("historique_prix_obligations", conn, if_exists="append", index=False)
                df_hist_bonds.to_csv(DB_PATH.parent / "historique_prix_obligations.csv", index=False)

            if not df_equities_sub.empty:
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
