"""Génère les fichiers d'exemple data/ du module VaR.

Produit des historiques simulés réalistes et reproductibles (graine fixe) :
- positions_obligations.csv (6 lignes, portefeuille d'environ 2 750 Md FCFA) ;
- historique_taux.csv (courbe UMOA quotidienne, 8 maturités pivots) ;
- historique_prix_obligations.csv (prix quotidiens dérivés de la courbe) ;
- positions_actions.csv (6 lignes BRVM, environ 380 Md FCFA) ;
- historique_cours_actions.csv (cours de clôture quotidiens).

Usage : python scripts/generer_donnees_var.py
"""

from __future__ import annotations

import sys
from datetime import date, timedelta
from pathlib import Path

import numpy as np

RACINE_BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RACINE_BACKEND))

from app.var_marche.portefeuille_data import (  # noqa: E402
    PositionObligation,
    prix_obligation_par_courbe,
)

REPERTOIRE_DATA = RACINE_BACKEND / "data"

NB_JOURS_OUVRES = 1_060
DERNIER_JOUR = date(2026, 7, 10)
GRAINE = 20260710

MATURITES_PIVOTS = (0.25, 0.5, 1.0, 2.0, 3.0, 5.0, 7.0, 10.0)
NIVEAUX_PIVOTS = (5.20, 5.45, 5.85, 6.10, 6.25, 6.50, 6.70, 6.95)

POSITIONS_OBLIGATIONS = [
    # isin, emetteur, nominal, coupon %, frequence, emission, echeance, quantite, prix (vide = courbe)
    ("CI0000012345", "Etat de Cote d'Ivoire", 10000, 5.90, 1, "2021-03-15", "2028-03-15", 62_000_000, "98.75"),
    ("SN0000067890", "Etat du Senegal", 10000, 6.15, 2, "2022-06-10", "2029-06-10", 48_000_000, "101.20"),
    ("BF0000054321", "Etat du Burkina Faso", 10000, 6.50, 1, "2020-11-20", "2027-11-20", 45_000_000, ""),
    ("BJ0000032109", "Etat du Benin", 10000, 6.35, 1, "2023-02-08", "2030-02-08", 52_000_000, ""),
    ("TG0000021098", "Etat du Togo", 10000, 6.80, 2, "2022-09-14", "2032-09-14", 38_000_000, ""),
    ("ML0000045678", "Etat du Mali", 10000, 7.05, 1, "2021-05-25", "2031-05-25", 30_000_000, ""),
]

POSITIONS_ACTIONS = [
    # ticker, libelle, secteur, quantite, cours initial FCFA, vol quotidienne
    ("SNTS", "Sonatel", "Telecommunications", 8_000_000, 21_500, 0.010),
    ("SGBC", "Societe Generale Cote d'Ivoire", "Banque", 4_000_000, 14_800, 0.011),
    ("PALC", "Palm Cote d'Ivoire", "Agro-industrie", 3_000_000, 7_400, 0.014),
    ("BOAB", "Bank of Africa Benin", "Banque", 5_000_000, 6_200, 0.012),
    ("NTLC", "Nestle Cote d'Ivoire", "Agro-industrie", 2_500_000, 8_900, 0.011),
    ("TTLC", "Total Cote d'Ivoire", "Distribution petroliere", 6_000_000, 2_650, 0.013),
]


def jours_ouvres_termines_le(dernier: date, nombre: int) -> list[date]:
    jours: list[date] = []
    courant = dernier
    while len(jours) < nombre:
        if courant.weekday() < 5:
            jours.append(courant)
        courant -= timedelta(days=1)
    return list(reversed(jours))


def generer_courbe(jours: list[date], generateur: np.random.Generator) -> dict[date, list[tuple[float, float]]]:
    """Courbe mean-reverting : un facteur commun + bruit propre par pivot."""

    nb_pivots = len(MATURITES_PIVOTS)
    niveaux = np.array(NIVEAUX_PIVOTS, dtype=float)
    taux = niveaux.copy()
    vitesse_retour = 0.02
    vol_facteur_commun = 0.018  # points de pourcentage par jour
    vol_propre = 0.006

    courbes: dict[date, list[tuple[float, float]]] = {}
    for jour in jours:
        choc_commun = generateur.normal(0.0, vol_facteur_commun)
        chocs_propres = generateur.normal(0.0, vol_propre, nb_pivots)
        taux = taux + vitesse_retour * (niveaux - taux) + choc_commun + chocs_propres
        taux = np.clip(taux, 3.0, 10.0)
        courbes[jour] = [
            (maturite, round(float(valeur), 4))
            for maturite, valeur in zip(MATURITES_PIVOTS, taux)
        ]
    return courbes


def ecrire_positions_obligations() -> list[PositionObligation]:
    lignes = ["isin;emetteur;devise;valeur_nominale;taux_coupon_pct;frequence_coupon;date_emission;date_echeance;quantite;prix_marche_pct"]
    positions = []
    for isin, emetteur, nominal, coupon, frequence, emission, echeance, quantite, prix in POSITIONS_OBLIGATIONS:
        lignes.append(
            f"{isin};{emetteur};XOF;{nominal};{coupon:.2f};{frequence};{emission};{echeance};{quantite};{prix}"
        )
        positions.append(
            PositionObligation(
                isin=isin,
                emetteur=emetteur,
                devise="XOF",
                valeur_nominale=float(nominal),
                taux_coupon_pct=coupon,
                frequence_coupon=frequence,
                date_emission=date.fromisoformat(emission),
                date_echeance=date.fromisoformat(echeance),
                quantite=quantite,
                prix_marche_pct=float(prix) if prix else None,
            )
        )
    (REPERTOIRE_DATA / "positions_obligations.csv").write_text(
        "\n".join(lignes) + "\n", encoding="utf-8"
    )
    return positions


def ecrire_historique_taux(courbes: dict[date, list[tuple[float, float]]]) -> None:
    lignes = ["date;maturite_annees;taux_pct"]
    for jour in sorted(courbes):
        for maturite, taux in courbes[jour]:
            maturite_txt = f"{maturite:g}"
            lignes.append(f"{jour.isoformat()};{maturite_txt};{taux:.4f}")
    (REPERTOIRE_DATA / "historique_taux.csv").write_text(
        "\n".join(lignes) + "\n", encoding="utf-8"
    )


def ecrire_prix_obligations(
    positions: list[PositionObligation],
    courbes: dict[date, list[tuple[float, float]]],
    generateur: np.random.Generator,
) -> None:
    lignes = ["date;isin;prix_pct"]
    for jour in sorted(courbes):
        points = courbes[jour]
        for position in positions:
            prix = prix_obligation_par_courbe(position, points, jour)
            bruit = generateur.normal(0.0, 0.03)  # bruit idiosyncratique en % du nominal
            lignes.append(f"{jour.isoformat()};{position.isin};{prix + bruit:.4f}")
    (REPERTOIRE_DATA / "historique_prix_obligations.csv").write_text(
        "\n".join(lignes) + "\n", encoding="utf-8"
    )


def ecrire_positions_actions() -> None:
    lignes = ["ticker;libelle;secteur;quantite"]
    for ticker, libelle, secteur, quantite, _, _ in POSITIONS_ACTIONS:
        lignes.append(f"{ticker};{libelle};{secteur};{quantite}")
    (REPERTOIRE_DATA / "positions_actions.csv").write_text(
        "\n".join(lignes) + "\n", encoding="utf-8"
    )


def ecrire_cours_actions(jours: list[date], generateur: np.random.Generator) -> None:
    """Cours en marche log-normale à innovations Student (queues épaisses)."""

    lignes = ["date;ticker;cours_cloture"]
    cours = {ticker: float(initial) for ticker, _, _, _, initial, _ in POSITIONS_ACTIONS}
    volatilites = {ticker: vol for ticker, _, _, _, _, vol in POSITIONS_ACTIONS}
    derive_annuelle = 0.06
    facteur_student = np.sqrt(5.0 / 3.0)

    for jour in jours:
        choc_marche = generateur.standard_t(5) / facteur_student
        for ticker, valeur in cours.items():
            vol = volatilites[ticker]
            choc_propre = generateur.standard_t(5) / facteur_student
            rendement = (
                derive_annuelle / 252.0
                + vol * (0.6 * choc_marche + 0.8 * choc_propre)
            )
            cours[ticker] = max(100.0, valeur * (1.0 + rendement))
            lignes.append(f"{jour.isoformat()};{ticker};{cours[ticker]:.0f}")
    (REPERTOIRE_DATA / "historique_cours_actions.csv").write_text(
        "\n".join(lignes) + "\n", encoding="utf-8"
    )


def principal() -> None:
    REPERTOIRE_DATA.mkdir(parents=True, exist_ok=True)
    generateur = np.random.default_rng(GRAINE)
    jours = jours_ouvres_termines_le(DERNIER_JOUR, NB_JOURS_OUVRES)

    positions = ecrire_positions_obligations()
    courbes = generer_courbe(jours, generateur)
    ecrire_historique_taux(courbes)
    ecrire_prix_obligations(positions, courbes, generateur)
    ecrire_positions_actions()
    ecrire_cours_actions(jours, generateur)
    print(f"Fichiers VaR générés dans {REPERTOIRE_DATA} ({len(jours)} jours ouvrés).")


if __name__ == "__main__":
    principal()
