"""Couche de données des portefeuilles pour le calcul de la VaR.

Sources de données, par ordre de priorité :
1. portefeuille importé via la boîte de dialogue « Importer données de
   marché » de l'application (feuilles Obligations/Actions), persisté en
   SQLite (table metadonnees_app, clé market_portfolios_payload_v1) — c'est
   la façon normale, pour un utilisateur de l'application, d'alimenter le
   calcul avec ses propres positions ;
2. fichiers CSV dans le répertoire data/ (encodage UTF-8, séparateur
   point-virgule, point décimal, dates AAAA-MM-JJ) — dépôt manuel réservé
   au développement/tests ou à un usage avancé ;
3. tables PostgreSQL équivalentes si la variable d'environnement
   VAR_POSTGRES_DSN est renseignée (mêmes colonnes, mêmes types) ;
4. si aucune donnée réelle : erreur explicite invitant à importer un
   portefeuille ou déposer les fichiers ; une série simulée reproductible
   n'est utilisée que si la variable d'environnement VAR_MODE_SIMULATION
   vaut 1 (démonstration).

Important : le portefeuille importé ne fournit que les POSITIONS actuelles
(quantités, prix courant) — la VaR historique/Monte-Carlo a en plus besoin
d'un historique de prix ou de taux (courbe quotidienne) pour reconstituer
les variations passées. Cet historique reste un fichier CSV (ou une table
Postgres) : un import de positions seul, sans historique disponible,
retombe donc sur la valorisation par courbe si elle existe, sinon sur une
erreur explicite (ou la simulation si activée).

Les fichiers déposés et le portefeuille importé sont pris en compte
automatiquement : le cache des séries est invalidé dès qu'un fichier change
(empreinte mtime + taille) ou qu'un nouvel import est enregistré (horodatage
de sauvegarde), sans redémarrage du serveur.

Convention de signe unique pour toute la chaîne VaR :
- une PERTE est POSITIVE, un GAIN est NÉGATIF ;
- perte(t) = V(t-1) - V(t), soit l'opposé du P&L comptable
  PnL(t) = V(t) - V(t-1) ;
- l'axe d'affichage va des gains (valeurs négatives, à gauche) vers les
  pertes sévères (valeurs positives, à droite).

Priorité de valorisation des obligations :
1. prix de marché quotidiens (historique_prix_obligations.csv) ;
2. valorisation par courbe de taux (historique_taux.csv), actualisation
   des flux sur la courbe interpolée linéairement ;
3. approche par sensibilité dV ~ -Duration modifiée x V x dTaux ;
4. mode simulation.
Actions : historique des cours (historique_cours_actions.csv), sinon
mode simulation.
"""

from __future__ import annotations

import csv
import json
import logging
import os
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path

import numpy as np

from app.core.runtime_paths import app_data_root

logger = logging.getLogger(__name__)

TYPES_PORTEFEUILLE = ("obligations", "actions")

_FICHIER_POSITIONS_OBLIGATIONS = "positions_obligations.csv"
_FICHIER_HISTORIQUE_TAUX = "historique_taux.csv"
_FICHIER_PRIX_OBLIGATIONS = "historique_prix_obligations.csv"
_FICHIER_POSITIONS_ACTIONS = "positions_actions.csv"
_FICHIER_COURS_ACTIONS = "historique_cours_actions.csv"

# Graines fixes du mode repli : une par type de portefeuille pour que les
# séries simulées soient reproductibles d'un appel à l'autre.
_GRAINE_SIMULATION = {"obligations": 20240101, "actions": 20240202}
_VOL_QUOTIDIENNE_SIMULATION = {"obligations": 0.003, "actions": 0.012}
_VALEUR_SIMULATION_FCFA = {"obligations": 2_751.4e9, "actions": 386.2e9}
_DDL_STUDENT_SIMULATION = 5
_PROFONDEUR_SIMULATION = 1_050

# Variation quotidienne au-delà de laquelle une valeur est signalée
# comme aberrante dans les journaux.
_SEUIL_VARIATION_ABERRANTE = 0.20


class ErreurDonneesVar(ValueError):
    """Erreur explicite de la couche de données (message en français)."""


class DonneesAbsentesError(ErreurDonneesVar):
    """Aucune donnée réelle disponible pour le portefeuille demandé."""


_FICHIERS_PAR_TYPE = {
    "obligations": (
        _FICHIER_POSITIONS_OBLIGATIONS,
        _FICHIER_HISTORIQUE_TAUX,
        _FICHIER_PRIX_OBLIGATIONS,
    ),
    "actions": (_FICHIER_POSITIONS_ACTIONS, _FICHIER_COURS_ACTIONS),
}

_FICHIERS_ATTENDUS_MESSAGE = {
    "obligations": (
        f"{_FICHIER_POSITIONS_OBLIGATIONS} accompagné de "
        f"{_FICHIER_PRIX_OBLIGATIONS} ou {_FICHIER_HISTORIQUE_TAUX}"
    ),
    "actions": f"{_FICHIER_POSITIONS_ACTIONS} et {_FICHIER_COURS_ACTIONS}",
}


def mode_simulation_actif() -> bool:
    """Le repli simulation n'est utilisé que sur demande explicite."""

    return os.environ.get("VAR_MODE_SIMULATION", "").strip().lower() in {
        "1",
        "true",
        "oui",
    }


@dataclass(frozen=True)
class PositionObligation:
    isin: str
    emetteur: str
    devise: str
    valeur_nominale: float
    taux_coupon_pct: float
    frequence_coupon: int
    date_emission: date
    date_echeance: date
    quantite: int
    prix_marche_pct: float | None


@dataclass(frozen=True)
class PositionAction:
    ticker: str
    libelle: str
    secteur: str
    quantite: int


@dataclass
class SeriePnl:
    """Résultat de get_serie_pnl : pertes en FCFA, convention perte positive."""

    valeur_portefeuille: float
    pertes: np.ndarray
    pertes_quotidiennes: np.ndarray
    source_donnees: str
    duration_modifiee: float | None = None
    variations_taux: np.ndarray | None = None
    avertissements: list[str] = field(default_factory=list)


def repertoire_data() -> Path:
    """Répertoire data/ (backend/data en développement, AppData packagé)."""

    return app_data_root()


# ---------------------------------------------------------------------------
# Lecture CSV / PostgreSQL
# ---------------------------------------------------------------------------


def _lire_csv(chemin: Path) -> list[dict[str, str]]:
    with chemin.open("r", encoding="utf-8-sig", newline="") as fichier:
        lecteur = csv.DictReader(fichier, delimiter=";")
        return [
            {
                (cle or "").strip(): (valeur or "").strip()
                for cle, valeur in ligne.items()
            }
            for ligne in lecteur
            if any((valeur or "").strip() for valeur in ligne.values())
        ]


_MARKET_PORTFOLIOS_SQLITE_KEY = "market_portfolios_payload_v1"
_MARKET_PORTFOLIOS_SAVED_AT_SQLITE_KEY = "market_portfolios_saved_at"

_FREQUENCE_COUPON_PAR_LIBELLE = {
    "annuel": "1",
    "annuelle": "1",
    "semestriel": "2",
    "semestrielle": "2",
    "trimestriel": "4",
    "trimestrielle": "4",
    "mensuel": "12",
    "mensuelle": "12",
}


def normaliser_frequence_coupon(valeur: str) -> str:
    """Convertit un libellé de fréquence de coupon (numérique ou en toutes
    lettres : Annuelle, Semestrielle, Trimestrielle, Mensuelle) vers le
    code numérique attendu par PositionObligation.frequence_coupon (1, 2, 4,
    12). Fonction publique : réutilisée par la couche d'import Excel (VaR
    historique) en plus de l'import du portefeuille marché."""

    brut = (valeur or "").strip()
    if not brut:
        return "1"
    try:
        nombre = float(brut.replace(",", "."))
        if nombre > 0:
            return str(int(round(nombre)))
    except ValueError:
        pass
    return _FREQUENCE_COUPON_PAR_LIBELLE.get(brut.strip().lower(), "1")


def _texte_date_import(valeur: object) -> str:
    if isinstance(valeur, dict) and valeur.get("type") == "datetime":
        valeur = valeur.get("value")
    brut = str(valeur or "").strip()
    return brut[:10] if brut else ""


def _lire_valeur_marche_portefeuilles_sqlite() -> dict | None:
    """Lit le payload JSON du portefeuille marché importé via l'application
    (table metadonnees_app, clé market_portfolios_payload_v1). Renvoie None
    si aucun import n'a encore été enregistré ou si la lecture échoue —
    dans ce cas les sources suivantes (CSV, Postgres) prennent le relais."""

    try:
        from database.connection import database_manager
    except Exception:
        return None
    try:
        with database_manager.read_connection() as connexion:
            ligne = connexion.execute(
                "SELECT valeur AS value FROM metadonnees_app WHERE cle = ?",
                (_MARKET_PORTFOLIOS_SQLITE_KEY,),
            ).fetchone()
    except Exception:
        logger.exception(
            "Lecture SQLite du portefeuille marché importé impossible ; "
            "passage au mode suivant."
        )
        return None
    if ligne is None or not str(ligne["value"] or "").strip():
        return None
    try:
        charge = json.loads(str(ligne["value"]))
    except (TypeError, ValueError):
        logger.warning("Portefeuille marché importé illisible (JSON invalide).")
        return None
    return charge if isinstance(charge, dict) else None


def _lire_positions_obligations_depuis_import(
    records: list,
) -> list[dict[str, str]]:
    lignes: list[dict[str, str]] = []
    for enregistrement in records:
        valeurs = (
            enregistrement.get("values") if isinstance(enregistrement, dict) else None
        )
        if not isinstance(valeurs, dict):
            continue
        isin = str(valeurs.get("ID Titre") or valeurs.get("ISIN") or "").strip()
        date_emission = _texte_date_import(valeurs.get("Date d'émission"))
        date_echeance = _texte_date_import(valeurs.get("Date d'échéance"))
        if not isin or not date_emission or not date_echeance:
            # Ligne insuffisamment renseignée pour une valorisation par
            # courbe/flux (ex : import minimal sans dates) : ignorée plutôt
            # que de faire échouer tout le portefeuille.
            continue
        prix_marche = valeurs.get("Cours actuel") or valeurs.get("Prix de marché")
        lignes.append(
            {
                "isin": isin,
                "emetteur": str(
                    valeurs.get("Emetteur") or valeurs.get("Émetteur / Société") or isin
                ),
                "devise": str(valeurs.get("Devise") or "XOF"),
                "valeur_nominale": str(valeurs.get("Valeur nominale unitaire") or "0"),
                "taux_coupon_pct": str(valeurs.get("Coupon (%)") or "0"),
                "frequence_coupon": normaliser_frequence_coupon(
                    str(valeurs.get("Fréquence de paiement des intérêts") or "")
                ),
                "date_emission": date_emission,
                "date_echeance": date_echeance,
                "quantite": str(
                    valeurs.get("quantités") or valeurs.get("Quantité") or "0"
                ),
                "prix_marche_pct": "" if prix_marche in (None, "") else str(prix_marche),
            }
        )
    return lignes


def _lire_positions_actions_depuis_import(records: list) -> list[dict[str, str]]:
    lignes: list[dict[str, str]] = []
    for enregistrement in records:
        valeurs = (
            enregistrement.get("values") if isinstance(enregistrement, dict) else None
        )
        if not isinstance(valeurs, dict):
            continue
        libelle = str(
            valeurs.get("Émetteur / Société") or valeurs.get("Emetteur") or ""
        ).strip()
        if not libelle:
            continue
        ticker = str(valeurs.get("Ticker") or libelle).strip()
        lignes.append(
            {
                "ticker": ticker,
                "libelle": libelle,
                "secteur": str(valeurs.get("Secteur") or "Non renseigné"),
                "quantite": str(
                    valeurs.get("Quantité") or valeurs.get("quantités") or "0"
                ),
            }
        )
    return lignes


def _charger_positions_importees(nom_table: str) -> list[dict[str, str]] | None:
    """Positions saisies via la boîte d'import « Portefeuille marché » de
    l'application, persistées en SQLite. Prime sur les CSV manuels : c'est
    la façon normale, pour un utilisateur de l'application, d'alimenter le
    calcul de VaR avec son propre portefeuille plutôt que de déposer des
    fichiers à la main. Renvoie None si aucun import exploitable n'est
    disponible pour ce type de portefeuille (les sources suivantes — CSV,
    Postgres — prennent alors le relais)."""

    if nom_table not in ("positions_obligations", "positions_actions"):
        return None
    charge = _lire_valeur_marche_portefeuilles_sqlite()
    if charge is None:
        return None
    datasets = charge.get("datasets")
    if not isinstance(datasets, dict):
        return None
    cle_type = "bonds" if nom_table == "positions_obligations" else "equities"
    jeu = datasets.get(cle_type)
    if not isinstance(jeu, dict):
        return None
    records = jeu.get("records")
    if not isinstance(records, list) or not records:
        return None
    if nom_table == "positions_obligations":
        lignes = _lire_positions_obligations_depuis_import(records)
    else:
        lignes = _lire_positions_actions_depuis_import(records)
    return lignes or None


def _lire_table_postgres(nom_table: str) -> list[dict[str, str]] | None:
    """Lit une table PostgreSQL équivalente au CSV si la base est configurée.

    Les CSV priment en environnement de développement : cette fonction n'est
    appelée que lorsque le fichier CSV correspondant est absent.
    """

    dsn = os.environ.get("VAR_POSTGRES_DSN", "").strip()
    if not dsn:
        return None
    try:
        from sqlalchemy import create_engine, text

        moteur = create_engine(dsn)
        with moteur.connect() as connexion:
            resultat = connexion.execute(text(f"SELECT * FROM {nom_table}"))
            colonnes = list(resultat.keys())
            return [
                {colonne: "" if valeur is None else str(valeur) for colonne, valeur in zip(colonnes, ligne)}
                for ligne in resultat.fetchall()
            ]
    except Exception:
        logger.exception(
            "Lecture PostgreSQL impossible pour la table %s ; passage au mode suivant.",
            nom_table,
        )
        return None


def _charger_lignes(nom_fichier: str, nom_table: str) -> list[dict[str, str]] | None:
    importees = _charger_positions_importees(nom_table)
    if importees is not None:
        return importees
    chemin = repertoire_data() / nom_fichier
    if chemin.exists():
        return _lire_csv(chemin)
    return _lire_table_postgres(nom_table)


def _date_iso(valeur: str, contexte: str) -> date:
    try:
        return date.fromisoformat(valeur)
    except ValueError as exc:
        raise ErreurDonneesVar(
            f"Date invalide '{valeur}' ({contexte}) : format attendu AAAA-MM-JJ."
        ) from exc


def _nombre(valeur: str, contexte: str) -> float:
    try:
        return float(valeur)
    except ValueError as exc:
        raise ErreurDonneesVar(
            f"Nombre invalide '{valeur}' ({contexte}) : point décimal attendu."
        ) from exc


# ---------------------------------------------------------------------------
# Chargement des positions et des historiques
# ---------------------------------------------------------------------------


def charger_positions_obligations() -> list[PositionObligation]:
    lignes = _charger_lignes(_FICHIER_POSITIONS_OBLIGATIONS, "positions_obligations")
    if not lignes:
        return []
    positions = []
    for ligne in lignes:
        prix_brut = ligne.get("prix_marche_pct", "")
        positions.append(
            PositionObligation(
                isin=ligne["isin"],
                emetteur=ligne["emetteur"],
                devise=ligne.get("devise", "XOF") or "XOF",
                valeur_nominale=_nombre(ligne["valeur_nominale"], f"valeur_nominale {ligne['isin']}"),
                taux_coupon_pct=_nombre(ligne["taux_coupon_pct"], f"taux_coupon_pct {ligne['isin']}"),
                frequence_coupon=int(_nombre(ligne["frequence_coupon"], f"frequence_coupon {ligne['isin']}")),
                date_emission=_date_iso(ligne["date_emission"], f"date_emission {ligne['isin']}"),
                date_echeance=_date_iso(ligne["date_echeance"], f"date_echeance {ligne['isin']}"),
                quantite=int(_nombre(ligne["quantite"], f"quantite {ligne['isin']}")),
                prix_marche_pct=_nombre(prix_brut, f"prix_marche_pct {ligne['isin']}") if prix_brut else None,
            )
        )
    return positions


def charger_positions_actions() -> list[PositionAction]:
    lignes = _charger_lignes(_FICHIER_POSITIONS_ACTIONS, "positions_actions")
    if not lignes:
        return []
    return [
        PositionAction(
            ticker=ligne["ticker"],
            libelle=ligne["libelle"],
            secteur=ligne["secteur"],
            quantite=int(_nombre(ligne["quantite"], f"quantite {ligne['ticker']}")),
        )
        for ligne in lignes
    ]


def charger_historique_taux() -> dict[date, list[tuple[float, float]]]:
    """Courbe quotidienne : date -> liste triée (maturité en années, taux %)."""

    lignes = _charger_lignes(_FICHIER_HISTORIQUE_TAUX, "historique_taux")
    if not lignes:
        return {}
    courbes: dict[date, list[tuple[float, float]]] = {}
    for ligne in lignes:
        jour = _date_iso(ligne["date"], "historique_taux.date")
        maturite = _nombre(ligne["maturite_annees"], "historique_taux.maturite_annees")
        taux = _nombre(ligne["taux_pct"], "historique_taux.taux_pct")
        courbes.setdefault(jour, []).append((maturite, taux))
    for points in courbes.values():
        points.sort(key=lambda point: point[0])
    return courbes


def charger_historique_prix_obligations() -> dict[date, dict[str, float]]:
    lignes = _charger_lignes(_FICHIER_PRIX_OBLIGATIONS, "historique_prix_obligations")
    if not lignes:
        return {}
    historique: dict[date, dict[str, float]] = {}
    for ligne in lignes:
        jour = _date_iso(ligne["date"], "historique_prix_obligations.date")
        historique.setdefault(jour, {})[ligne["isin"]] = _nombre(
            ligne["prix_pct"], f"prix_pct {ligne['isin']}"
        )
    return historique


def charger_historique_cours_actions() -> dict[date, dict[str, float]]:
    lignes = _charger_lignes(_FICHIER_COURS_ACTIONS, "historique_cours_actions")
    if not lignes:
        return {}
    historique: dict[date, dict[str, float]] = {}
    for ligne in lignes:
        jour = _date_iso(ligne["date"], "historique_cours_actions.date")
        historique.setdefault(jour, {})[ligne["ticker"]] = _nombre(
            ligne["cours_cloture"], f"cours_cloture {ligne['ticker']}"
        )
    return historique


# ---------------------------------------------------------------------------
# Valorisation des obligations
# ---------------------------------------------------------------------------


def interpoler_taux(points: list[tuple[float, float]], maturite: float) -> float:
    """Interpolation linéaire entre maturités pivots, extrapolation plate."""

    if not points:
        raise ErreurDonneesVar("Courbe de taux vide : interpolation impossible.")
    if maturite <= points[0][0]:
        return points[0][1]
    if maturite >= points[-1][0]:
        return points[-1][1]
    for (m_gauche, t_gauche), (m_droite, t_droite) in zip(points, points[1:]):
        if m_gauche <= maturite <= m_droite:
            if m_droite == m_gauche:
                return t_gauche
            poids = (maturite - m_gauche) / (m_droite - m_gauche)
            return t_gauche + poids * (t_droite - t_gauche)
    return points[-1][1]


def flux_obligation(position: PositionObligation, jour: date) -> list[tuple[float, float]]:
    """Flux futurs (échéance en années, montant par titre) vus depuis `jour`.

    Les dates de coupon sont reconstruites à rebours depuis l'échéance avec
    un pas de 12 / frequence_coupon mois.
    """

    frequence = max(1, position.frequence_coupon)
    coupon = position.valeur_nominale * position.taux_coupon_pct / 100.0 / frequence

    flux = []
    for date_coupon in _dates_coupons(position):
        if date_coupon <= jour:
            continue
        echeance_annees = (date_coupon - jour).days / 365.25
        montant = coupon
        if date_coupon == position.date_echeance:
            montant += position.valeur_nominale
        flux.append((echeance_annees, montant))
    return flux


def prix_obligation_par_courbe(
    position: PositionObligation,
    points_courbe: list[tuple[float, float]],
    jour: date,
) -> float:
    """Prix en % du nominal par actualisation des flux sur la courbe du jour."""

    flux = flux_obligation(position, jour)
    if not flux:
        return 100.0
    valeur_actuelle = 0.0
    for echeance, montant in flux:
        taux = interpoler_taux(points_courbe, echeance) / 100.0
        valeur_actuelle += montant / (1.0 + taux) ** echeance
    return valeur_actuelle / position.valeur_nominale * 100.0


def duration_modifiee_obligation(
    position: PositionObligation,
    points_courbe: list[tuple[float, float]],
    jour: date,
) -> float:
    """Duration modifiée par choc parallèle de +/- 1 point de base."""

    choc = 0.0001
    points_hausse = [(m, t + choc * 100) for m, t in points_courbe]
    points_baisse = [(m, t - choc * 100) for m, t in points_courbe]
    prix_central = prix_obligation_par_courbe(position, points_courbe, jour)
    if prix_central <= 0:
        return 0.0
    prix_hausse = prix_obligation_par_courbe(position, points_hausse, jour)
    prix_baisse = prix_obligation_par_courbe(position, points_baisse, jour)
    return (prix_baisse - prix_hausse) / (2.0 * choc * prix_central)


# ---------------------------------------------------------------------------
# Construction des séries de valeurs de marché V(t)
# ---------------------------------------------------------------------------


def _jours_ouvres(debut: date, fin: date) -> list[date]:
    jours = []
    courant = debut
    while courant <= fin:
        if courant.weekday() < 5:
            jours.append(courant)
        courant += timedelta(days=1)
    return jours


def _completer_dates_ouvrees(
    valeurs_par_date: dict[date, float],
    avertissements: list[str],
    contexte: str,
) -> tuple[list[date], np.ndarray]:
    """Reporte la dernière valeur connue sur les jours ouvrés manquants."""

    dates_connues = sorted(valeurs_par_date)
    jours = _jours_ouvres(dates_connues[0], dates_connues[-1])
    valeurs = np.empty(len(jours))
    manquantes = 0
    derniere = valeurs_par_date[dates_connues[0]]
    for indice, jour in enumerate(jours):
        if jour in valeurs_par_date:
            derniere = valeurs_par_date[jour]
        else:
            manquantes += 1
        valeurs[indice] = derniere
    if manquantes:
        message = (
            f"{contexte} : {manquantes} date(s) ouvrée(s) manquante(s), "
            "report de la dernière valeur connue."
        )
        avertissements.append(message)
        logger.warning(message)
    return jours, valeurs


def _signaler_variations_aberrantes(
    jours: list[date], valeurs: np.ndarray, contexte: str
) -> None:
    for indice in range(1, len(valeurs)):
        precedente = valeurs[indice - 1]
        if precedente == 0:
            continue
        variation = abs(valeurs[indice] / precedente - 1.0)
        if variation > _SEUIL_VARIATION_ABERRANTE:
            logger.warning(
                "%s : variation quotidienne aberrante de %.1f %% le %s.",
                contexte,
                variation * 100,
                jours[indice].isoformat(),
            )


def _coupons_verses_par_jour(
    positions: list[PositionObligation], jours: list[date]
) -> np.ndarray:
    """Coupons encaissés chaque jour (FCFA), rattachés au jour ouvré suivant.

    Le prix par actualisation des flux chute mécaniquement du montant du
    coupon à son détachement ; réintégrer le coupon encaissé transforme la
    série V(t) en indice de rendement total et évite de compter ce
    détachement comme une perte de marché.
    """

    coupons = np.zeros(len(jours))
    for position in positions:
        frequence = max(1, position.frequence_coupon)
        montant = (
            position.quantite
            * position.valeur_nominale
            * position.taux_coupon_pct
            / 100.0
            / frequence
        )
        for jour_flux in _dates_coupons(position):
            if not jours[0] < jour_flux <= jours[-1]:
                continue
            indice = int(np.searchsorted(np.array(jours, dtype="datetime64[D]"), np.datetime64(jour_flux)))
            if indice < len(jours):
                coupons[indice] += montant
    return coupons


def _dates_coupons(position: PositionObligation) -> list[date]:
    """Dates de coupon reconstruites à rebours depuis l'échéance."""

    frequence = max(1, position.frequence_coupon)
    pas_mois = 12 // frequence if frequence in (1, 2, 3, 4, 6, 12) else round(12 / frequence)
    dates_flux: list[date] = []
    courante = position.date_echeance
    while courante > position.date_emission:
        dates_flux.append(courante)
        mois_total = courante.year * 12 + (courante.month - 1) - pas_mois
        annee, mois = divmod(mois_total, 12)
        jour_mois = min(courante.day, 28)
        courante = date(annee, mois + 1, jour_mois)
    return sorted(dates_flux)


def _duration_et_variations_taux(
    positions: list[PositionObligation],
    courbes: dict[date, list[tuple[float, float]]] | None = None,
) -> tuple[float | None, np.ndarray | None]:
    """Duration modifiée du portefeuille et variations quotidiennes de taux.

    La duration est pondérée par les valeurs de marché du dernier jour de
    courbe ; les variations sont celles du taux interpolé à la maturité
    résiduelle moyenne. Ces deux séries calibrent la simulation Monte-Carlo
    des obligations. Retourne (None, None) si aucune courbe n'est disponible.
    """

    if courbes is None:
        courbes = charger_historique_taux()
    if not courbes or not positions:
        return None, None

    dernier_jour = sorted(courbes)[-1]
    points_dernier = courbes[dernier_jour]
    poids_total = 0.0
    duration_ponderee = 0.0
    maturite_ponderee = 0.0
    for position in positions:
        prix = prix_obligation_par_courbe(position, points_dernier, dernier_jour)
        valeur = position.quantite * prix / 100.0 * position.valeur_nominale
        duration = duration_modifiee_obligation(position, points_dernier, dernier_jour)
        maturite = max(0.0, (position.date_echeance - dernier_jour).days / 365.25)
        poids_total += valeur
        duration_ponderee += valeur * duration
        maturite_ponderee += valeur * maturite
    if poids_total <= 0:
        return None, None
    duration_portefeuille = duration_ponderee / poids_total
    maturite_moyenne = maturite_ponderee / poids_total

    jours_courbe = sorted(courbes)
    taux_pivot = np.array(
        [interpoler_taux(courbes[jour], maturite_moyenne) for jour in jours_courbe]
    )
    variations_taux = np.diff(taux_pivot) / 100.0
    return duration_portefeuille, variations_taux


_MAX_TITRES_CITES_DANS_ERREUR = 8


def _message_titres_sans_historique(
    absents: list[str],
    nom_historique: str,
    nom_identifiant: str,
) -> str:
    """Message de couverture incomplète, lisible même pour un portefeuille de
    plusieurs dizaines de titres : dénombrement + premiers identifiants,
    plutôt que la liste exhaustive (illisible à l'écran)."""

    extrait = ", ".join(absents[:_MAX_TITRES_CITES_DANS_ERREUR])
    reste = len(absents) - _MAX_TITRES_CITES_DANS_ERREUR
    suite = f" et {reste} autres" if reste > 0 else ""
    return (
        f"{len(absents)} titre(s) du portefeuille sans donnée dans "
        f"{nom_historique} : {extrait}{suite}. L'historique importé doit "
        f"couvrir chaque titre du portefeuille (même {nom_identifiant} "
        "que les positions)."
    )


def _serie_obligations(
    avertissements: list[str],
) -> tuple[np.ndarray, float, float | None, np.ndarray | None] | None:
    """Portefeuille obligataire : (série de rendement total, valeur actuelle,
    duration modifiée, variations de taux).

    La série retournée est l'indice de rendement total V(t) + coupons
    cumulés encaissés, afin que les détachements de coupon ne soient pas
    comptés comme des pertes de marché. Retourne None si aucune donnée
    réelle n'est disponible (mode simulation).
    """

    positions = charger_positions_obligations()
    if not positions:
        return None

    historique_prix = charger_historique_prix_obligations()
    if historique_prix:
        isins_positions = {position.isin for position in positions}
        isins_historique = set()
        for prix_du_jour in historique_prix.values():
            isins_historique.update(prix_du_jour)
        absents = sorted(isins_positions - isins_historique)
        if absents:
            raise ErreurDonneesVar(
                _message_titres_sans_historique(
                    absents, "l'historique des prix", "ID Titre"
                )
            )

        valeurs_par_date: dict[date, float] = {}
        derniers_prix: dict[str, float] = {}
        for jour in sorted(historique_prix):
            derniers_prix.update(historique_prix[jour])
            if not all(position.isin in derniers_prix for position in positions):
                continue
            valeurs_par_date[jour] = sum(
                position.quantite
                * derniers_prix[position.isin]
                / 100.0
                * position.valeur_nominale
                for position in positions
            )
        if not valeurs_par_date:
            return None
        jours, valeurs = _completer_dates_ouvrees(
            valeurs_par_date, avertissements, "Prix obligations"
        )
        _signaler_variations_aberrantes(jours, valeurs, "Portefeuille obligations")
        # Même en valorisation par prix, la courbe (si présente) calibre la
        # duration et les variations de taux de la simulation Monte-Carlo.
        duration, variations_taux = _duration_et_variations_taux(positions)
        serie_rendement_total = valeurs + np.cumsum(
            _coupons_verses_par_jour(positions, jours)
        )
        return serie_rendement_total, float(valeurs[-1]), duration, variations_taux

    courbes = charger_historique_taux()
    if courbes:
        valeurs_par_date = {}
        for jour in sorted(courbes):
            points = courbes[jour]
            valeurs_par_date[jour] = sum(
                position.quantite
                * prix_obligation_par_courbe(position, points, jour)
                / 100.0
                * position.valeur_nominale
                for position in positions
            )
        jours, valeurs = _completer_dates_ouvrees(
            valeurs_par_date, avertissements, "Courbe de taux"
        )
        _signaler_variations_aberrantes(jours, valeurs, "Portefeuille obligations")
        duration, variations_taux = _duration_et_variations_taux(positions, courbes)
        serie_rendement_total = valeurs + np.cumsum(
            _coupons_verses_par_jour(positions, jours)
        )
        return serie_rendement_total, float(valeurs[-1]), duration, variations_taux

    # Approche par sensibilité : sans historique de prix ni courbe, la
    # formule dV ~ -Duration modifiée x V x dTaux est inapplicable faute de
    # série de taux ; on bascule donc en mode simulation.
    return None


def _serie_actions(avertissements: list[str]) -> tuple[list[date], np.ndarray] | None:
    positions = charger_positions_actions()
    if not positions:
        return None
    historique = charger_historique_cours_actions()
    if not historique:
        return None

    tickers_positions = {position.ticker for position in positions}
    tickers_historique = set()
    for cours_du_jour in historique.values():
        tickers_historique.update(cours_du_jour)
    absents = sorted(tickers_positions - tickers_historique)
    if absents:
        raise ErreurDonneesVar(
            _message_titres_sans_historique(
                absents, "l'historique des cours", "ID Instrument"
            )
        )

    valeurs_par_date: dict[date, float] = {}
    derniers_cours: dict[str, float] = {}
    for jour in sorted(historique):
        derniers_cours.update(historique[jour])
        if not all(position.ticker in derniers_cours for position in positions):
            continue
        valeurs_par_date[jour] = sum(
            position.quantite * derniers_cours[position.ticker]
            for position in positions
        )
    if not valeurs_par_date:
        return None
    jours, valeurs = _completer_dates_ouvrees(
        valeurs_par_date, avertissements, "Cours actions"
    )
    _signaler_variations_aberrantes(jours, valeurs, "Portefeuille actions")
    return jours, valeurs


def _serie_simulee(type_portefeuille: str) -> np.ndarray:
    """Série V(t) simulée, réaliste et reproductible (graine fixe par type).

    Rendements en loi de Student à 5 degrés de liberté (queues épaisses),
    normalisés pour respecter la volatilité quotidienne cible.
    """

    generateur = np.random.default_rng(_GRAINE_SIMULATION[type_portefeuille])
    volatilite = _VOL_QUOTIDIENNE_SIMULATION[type_portefeuille]
    tirages = generateur.standard_t(_DDL_STUDENT_SIMULATION, _PROFONDEUR_SIMULATION)
    facteur_normalisation = np.sqrt(
        _DDL_STUDENT_SIMULATION / (_DDL_STUDENT_SIMULATION - 2)
    )
    rendements = tirages / facteur_normalisation * volatilite
    valeur_initiale = _VALEUR_SIMULATION_FCFA[type_portefeuille]
    return valeur_initiale * np.cumprod(1.0 + rendements)


_SeriePayload = tuple[
    tuple[float, ...],
    float,
    str,
    float | None,
    tuple[float, ...] | None,
    tuple[str, ...],
]

# Cache par type de portefeuille : (empreinte des fichiers, série).
_cache_series: dict[str, tuple[tuple, _SeriePayload]] = {}


def _empreinte_portefeuille_importe_sqlite() -> str | None:
    """Horodatage de la dernière sauvegarde du portefeuille marché importé
    (métadonnée mise à jour à chaque import réussi côté API) — inclus dans
    l'empreinte de cache pour qu'un import via l'application soit pris en
    compte immédiatement, sans attendre qu'un fichier CSV change."""

    try:
        from database.connection import database_manager
    except Exception:
        return None
    try:
        with database_manager.read_connection() as connexion:
            ligne = connexion.execute(
                "SELECT valeur AS value FROM metadonnees_app WHERE cle = ?",
                (_MARKET_PORTFOLIOS_SAVED_AT_SQLITE_KEY,),
            ).fetchone()
    except Exception:
        return None
    if ligne is None:
        return None
    valeur = str(ligne["value"] or "").strip()
    return valeur or None


def _empreinte_donnees(type_portefeuille: str) -> tuple:
    """Empreinte des fichiers sources : répertoire, mtime et taille, plus
    l'horodatage du dernier import de portefeuille enregistré en SQLite.

    Toute création, modification ou suppression d'un fichier, ou tout
    nouvel import via l'application, change l'empreinte et force le
    recalcul de la série : les nouvelles données sont donc chargées
    automatiquement, sans redémarrage.
    """

    racine = repertoire_data()
    parts: list[object] = [
        str(racine),
        mode_simulation_actif(),
        _empreinte_portefeuille_importe_sqlite(),
    ]
    for nom in _FICHIERS_PAR_TYPE[type_portefeuille]:
        chemin = racine / nom
        if chemin.exists():
            stat = chemin.stat()
            parts.append((nom, stat.st_mtime_ns, stat.st_size))
        else:
            parts.append((nom, None, None))
    return tuple(parts)


def _serie_valeurs(type_portefeuille: str) -> _SeriePayload:
    # La cle porte l'espace de travail : chaque compte a sa propre base, et
    # une cle commune servirait a l'un la serie calculee pour l'autre.
    from database.connection import espace_courant

    cle = f"{espace_courant().name}|{type_portefeuille}"
    empreinte = _empreinte_donnees(type_portefeuille)
    en_cache = _cache_series.get(cle)
    if en_cache is not None and en_cache[0] == empreinte:
        return en_cache[1]
    serie = _construire_serie_valeurs(type_portefeuille)
    _cache_series[cle] = (empreinte, serie)
    return serie


def _construire_serie_valeurs(type_portefeuille: str) -> _SeriePayload:
    avertissements: list[str] = []
    if type_portefeuille == "obligations":
        resultat = _serie_obligations(avertissements)
        if resultat is not None:
            valeurs, valeur_actuelle, duration, variations_taux = resultat
            return (
                tuple(valeurs),
                valeur_actuelle,
                "reelles",
                duration,
                tuple(variations_taux) if variations_taux is not None else None,
                tuple(avertissements),
            )
    else:
        resultat_actions = _serie_actions(avertissements)
        if resultat_actions is not None:
            _, valeurs = resultat_actions
            return (
                tuple(valeurs),
                float(valeurs[-1]),
                "reelles",
                None,
                None,
                tuple(avertissements),
            )

    if not mode_simulation_actif():
        # Message ciblé : si le portefeuille est bien importé, le blocage
        # vient de l'absence de source de valorisation, pas de l'import.
        if type_portefeuille == "obligations" and charger_positions_obligations():
            raise DonneesAbsentesError(
                "Portefeuille obligations importé, mais aucune source de "
                "valorisation disponible. Actualisez la courbe des taux "
                "(onglet « Courbe des Taux ») pour activer les VaR "
                "paramétrique et Monte-Carlo, ou importez un historique de "
                "prix pour la VaR historique."
            )
        if type_portefeuille == "actions" and charger_positions_actions():
            raise DonneesAbsentesError(
                "Portefeuille actions importé, mais aucun historique de "
                "cours disponible : importez l'historique des cours pour "
                "évaluer la Value at Risk."
            )
        raise DonneesAbsentesError(
            f"Aucune donnée réelle trouvée pour le portefeuille "
            f"{type_portefeuille}. Importez un portefeuille via « Importer "
            "données de marché », ou déposez "
            f"{_FICHIERS_ATTENDUS_MESSAGE[type_portefeuille]} dans "
            f"{repertoire_data()} ; les nouvelles données seront chargées "
            "automatiquement."
        )

    logger.warning(
        "Aucune donnée réelle pour le portefeuille %s : série simulée utilisée "
        "(VAR_MODE_SIMULATION actif).",
        type_portefeuille,
    )
    valeurs_simulees = _serie_simulee(type_portefeuille)
    return (
        tuple(valeurs_simulees),
        float(valeurs_simulees[-1]),
        "simulation",
        None,
        None,
        tuple(avertissements),
    )


def invalider_cache_series() -> None:
    """Vide le cache des séries (les fichiers sont de toute façon
    surveillés par empreinte à chaque appel)."""

    _cache_series.clear()


def get_serie_pnl(
    type_portefeuille: str,
    fenetre_jours: int,
    horizon_jours: int,
) -> SeriePnl:
    """Point d'entrée unique de la couche de données.

    Retourne la valeur actuelle du portefeuille (FCFA), la série des pertes
    quotidiennes perte(t) = V(t-1) - V(t) limitée à la fenêtre demandée puis
    mise à l'échelle par racine(horizon_jours), et la source des données.
    """

    if type_portefeuille not in TYPES_PORTEFEUILLE:
        raise ErreurDonneesVar(
            f"Type de portefeuille inconnu : '{type_portefeuille}'. "
            "Valeurs acceptées : obligations, actions."
        )

    (
        valeurs_tuple,
        valeur_actuelle,
        source,
        duration,
        variations_taux,
        avertissements,
    ) = _serie_valeurs(type_portefeuille)
    valeurs = np.array(valeurs_tuple)

    avertissements = list(avertissements)
    profondeur_disponible = len(valeurs) - 1
    if profondeur_disponible == 0:
        # Valorisation du jour disponible (positions + courbe ou prix) mais
        # aucun historique : la série de pertes est vide. Les VaR
        # paramétrique et Monte-Carlo basculent alors en mode réglementaire
        # (volatilité forfaitaire x sensibilité x valeur du portefeuille) ;
        # la VaR historique, elle, refusera explicitement côté endpoint.
        message = (
            f"Aucun historique de valorisation pour le portefeuille "
            f"{type_portefeuille} : VaR paramétrique et Monte-Carlo "
            "calculées en mode réglementaire (volatilité forfaitaire). "
            "La VaR historique nécessite un historique de prix importé."
        )
        avertissements.append(message)
        logger.info(message)
    elif profondeur_disponible < fenetre_jours:
        raise ErreurDonneesVar(
            f"Profondeur d'historique insuffisante pour le portefeuille "
            f"{type_portefeuille} : {profondeur_disponible} observations "
            f"disponibles pour une fenêtre demandée de {fenetre_jours} jours."
        )

    # Convention de signe : perte positive, gain négatif.
    pertes_quotidiennes = -np.diff(valeurs)[-fenetre_jours:]
    pertes = pertes_quotidiennes * np.sqrt(horizon_jours)

    variations = None
    if variations_taux is not None:
        variations = np.array(variations_taux)[-fenetre_jours:]

    return SeriePnl(
        valeur_portefeuille=valeur_actuelle,
        pertes=pertes,
        pertes_quotidiennes=pertes_quotidiennes,
        source_donnees=source,
        duration_modifiee=duration,
        variations_taux=variations,
        avertissements=list(avertissements),
    )
