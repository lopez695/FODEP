"""Construction du Formulaire de Déclaration Prudentielle (FODEP).

L'export part du formulaire officiel de la BCEAO, livré vierge avec
l'application (`modele_fodep.xlsx`), et n'écrit que les cellules de saisie.
Sa mise en page, ses libellés, ses codes DISPRU et ses coefficients
réglementaires ne sont jamais reconstruits : ils font foi.

Les montants sont écrits en valeur, jamais en formule. C'est ce que prévoit la
notice technique — « à l'exception de l'EP01, le formulaire ne contient aucune
formule » — et cela garantit que le classeur exporté affiche exactement les
chiffres calculés par l'application, y compris ouvert dans un tableur qui ne
recalcule pas.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date
from io import BytesIO
from typing import Any

from openpyxl import load_workbook
from openpyxl.cell.cell import MergedCell

from app.core.bceao_calculations import calculate_fonds_propres
from app.core.calculations import convert_currency_amount
from app.core.natures_immobilisations import (
    NATURE_IMMO_EXPLOITATION,
    NATURE_IMMO_HORS_EXPLOITATION,
    NATURE_IMMO_INCORPORELLE,
)
from app.core.runtime_paths import resource_path
from app.market.services import resolve_market_capital
from app.groupes_clients.models import LIBELLES_LIENS
from app.participations.services import calculer_synthese, lister_participations
from app.rapports.fodep import agregation
from app.rapports.fodep.perimetre import (
    BASE_DE_DECLARATION,
    ETATS_ALIMENTES,
    ETATS_DECLARES_A_ZERO,
    PREMIERE_COLONNE_NUMERIQUE,
)
from app.rapports.fodep.saisies import appliquer_saisies
from app.rapports.fodep.agregation import (
    ETAT_PAR_CATEGORIE,
    LIGNES_EP09,
    LIGNES_EP09_AGREGEES,
    LIGNES_EP10,
    LIGNES_EP10_AGREGEES,
    LIGNE_TOTAL_EP09,
    LIGNE_TOTAL_EP10,
    LIGNES_TOTALISEES_EP09,
    LIGNES_TOTALISEES_EP10,
    FCEC_FODEP,
    SyntheseCredit,
    agreger_risque_credit,
    aligner_sur_les_paliers,
    categorie_fodep,
    flottant,
)
from app.rapports.fodep.reserves import (
    Reserve,
    a_verifier,
    convention,
    information,
)
from app.rapports.fodep.disposition import (
    BLOC_AUTRES_HORS_BILAN,
    BLOC_BILAN,
    BLOC_CONTREPARTIE,
    BLOC_ENGAGEMENT_FINANCEMENT,
    completer_a_zero,
    completer_etat_a_zero,
    indexer_codes_dispru,
    lire_disposition_categorie,
    lire_etats_requis,
)
from app.risque_operationnel.services import (
    calcul_aib,
    calcul_as,
    get_aib_parametres,
    get_as_parametres,
    get_pertes_seuils,
)
from database.connection import database_manager
from database.repositories.exposure_repository import exposure_repository


CHEMIN_MODELE = resource_path("app", "rapports", "fodep", "modele_fodep.xlsx")

DEVISE_DECLARATION = "XOF"
UN_MILLION = 1_000_000

# Multiplicateur imposé par l'EP21 pour passer de l'exigence de fonds propres
# aux actifs pondérés du risque opérationnel. Le module Risque Opérationnel de
# l'application applique, lui, 1 / ratio de solvabilité minimal : le FODEP
# suit sa propre règle, et l'écart est signalé à l'utilisateur.
MULTIPLICATEUR_APR_FODEP = 12.5

# Seuil au-delà duquel une contrepartie est un « grand risque » à déclarer sur
# l'EP29, exprimé en part des fonds propres de base T1 (§ Division des risques).
SEUIL_GRAND_RISQUE = 0.10

# Catégories qui ne portent pas de risque de contrepartie et sont donc hors du
# champ de la division des risques : souverains et autres actifs.
CATEGORIES_HORS_DIVISION = frozenset({"a", "k"})

# Le périmètre de la déclaration est défini dans `perimetre.py` : le catalogue
# des saisies manuelles le lit aussi, et le garder ici créerait un cycle.

# Bornes supérieures, en mois de maturité résiduelle, des catégories
# d'échéances de l'EP31. Mensuelles la première année, trimestrielles ensuite,
# puis élargies. Deux colonnes les suivent : « plus de 10 ans » et
# « échéance non définie ».
BORNES_ECHEANCE_EP31: tuple[int, ...] = (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
    15, 18, 21, 24, 27, 30, 33, 36,
    60, 120,
)

# Normes de l'EP01 que l'application ne mesure toujours pas : immobilisations
# hors exploitation, total des immobilisations et participations, prêts aux
# actionnaires et dirigeants. Les trois limites sur les participations dans
# les entités commerciales (RA006 à RA008) sont désormais calculées.
NORMES_EP01_NON_MESUREES: tuple[str, ...] = ("RA009", "RA010", "RA011")

COLONNE_B = 2
COLONNE_C, COLONNE_D, COLONNE_E, COLONNE_F = 3, 4, 5, 6
COLONNE_G, COLONNE_H, COLONNE_I, COLONNE_J = 7, 8, 9, 10
COLONNE_K, COLONNE_L, COLONNE_M = 11, 12, 13


@dataclass
class ResultatFodep:
    """Classeur FODEP produit, accompagné de ses réserves de lecture."""

    contenu: bytes
    date_arrete: date
    anomalies: list[Reserve] = field(default_factory=list)


@dataclass
class ClasseurFodep:
    """Le classeur renseigné, encore ouvert, avec ce qui l'accompagne.

    L'aperçu n'a que faire d'un fichier : il relit ce que l'application vient
    d'écrire. Lui rendre le classeur en mémoire lui épargne une sauvegarde et
    un rechargement — huit secondes sur une déclaration, pour retrouver
    exactement l'état qu'on tenait déjà.

    Celui qui reçoit ce classeur en devient responsable et doit le refermer.
    """

    classeur: object
    date_arrete: date
    anomalies: list[Reserve] = field(default_factory=list)


def nom_fichier_fodep(date_arrete: date) -> str:
    """Nom de fichier attendu pour une déclaration à une date d'arrêté."""

    return f"FODEP_{date_arrete.strftime('%d%m%Y')}.xlsx"


def en_millions(montant_fcfa: float) -> int:
    """Convertit un montant en francs vers l'unité de déclaration du FODEP.

    La notice impose l'arrondi au million inférieur en deçà de 500 000 FCFA et
    au million supérieur au-delà (§ 2.3), y compris pour les montants négatifs
    que portent les colonnes de déduction et d'ajustement.
    """

    if not montant_fcfa:
        return 0
    signe = 1 if montant_fcfa >= 0 else -1
    return signe * int((abs(montant_fcfa) + UN_MILLION / 2) // UN_MILLION)


def _ecrire(feuille, ligne: int, colonne: int, valeur: Any) -> None:
    """Écrit une valeur, en atteignant l'ancre des cellules fusionnées.

    Le formulaire fusionne certaines colonnes sur tout un bloc : un ratio
    calculé une fois pour plusieurs lignes, un excédent qui vaut pour
    l'ensemble. Seule la cellule en haut à gauche d'une fusion accepte une
    valeur ; viser une autre lèverait une erreur d'attribut en lecture seule.
    """

    if not ligne:
        return
    cellule = feuille.cell(row=ligne, column=colonne)
    if isinstance(cellule, MergedCell):
        for plage in feuille.merged_cells.ranges:
            if (ligne, colonne) in plage.cells:
                feuille.cell(row=plage.min_row, column=plage.min_col, value=valeur)
                return
        return
    cellule.value = valeur


def _ecrire_montant(feuille, ligne: int, colonne: int, montant_fcfa: float) -> None:
    _ecrire(feuille, ligne, colonne, en_millions(montant_fcfa))


# ─── Collecte des données de l'application ────────────────────────────────


def _lire_fonds_propres() -> dict[str, float]:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            "SELECT * FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1"
        ).fetchone()
    return dict(ligne) if ligne else {}


def _lire_risque_marche() -> dict[str, float]:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            "SELECT * FROM risque_marche ORDER BY date_analyse DESC LIMIT 1"
        ).fetchone()
    return resolve_market_capital(dict(ligne) if ligne else {})


# ─── EP03 : fonds propres sur base individuelle ───────────────────────────


def _remplir_ep03(classeur, donnees_fp: dict[str, float]) -> tuple[dict[str, float], list[Reserve]]:
    """Reporte les fonds propres réglementaires, et retourne leurs agrégats."""

    feuille = classeur["EP03"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    capital = flottant(donnees_fp.get("capital_ordinaire"))
    reserves = flottant(donnees_fp.get("reserves"))
    report = flottant(donnees_fp.get("resultats_report"))
    resultat = flottant(donnees_fp.get("resultat_eligible"))
    deductions_cet1 = flottant(donnees_fp.get("deductions_prud_cet1"))
    instruments_at1 = flottant(donnees_fp.get("instruments_at1"))
    primes_at1 = flottant(donnees_fp.get("primes_emission_at1"))
    deductions_at1 = flottant(donnees_fp.get("deductions_prud_at1"))
    dettes_t2 = flottant(donnees_fp.get("dettes_subordonnees_t2"))
    provisions_t2 = flottant(donnees_fp.get("provisions_generales_t2"))
    deductions_t2 = flottant(donnees_fp.get("deductions_prud_t2"))

    # Le FODEP sépare ce que l'application agrège : un report à nouveau ou un
    # résultat négatif ne se déclare pas en creux sur la ligne créditrice mais
    # sur sa propre ligne de déduction.
    montants: dict[str, float] = {
        "FPI01": capital,
        "FPI02": 0.0,
        "FPI03": 0.0,
        "FPI04": reserves,
        "FPI05": max(report, 0.0),
        "FPI06": max(resultat, 0.0),
        "FPI07": 0.0,
        "FPI09": -max(-report, 0.0),
        "FPI10": -max(-resultat, 0.0),
    }
    cet1_avant_deductions = sum(
        montants[code] for code in ("FPI01", "FPI02", "FPI03", "FPI04", "FPI05", "FPI06", "FPI07")
    )
    montants["FPI08"] = cet1_avant_deductions
    cet1_ajuste = cet1_avant_deductions + montants["FPI09"] + montants["FPI10"]
    montants["FPI14"] = cet1_ajuste
    montants["FPI15"] = cet1_ajuste
    montants["FPI16"] = cet1_ajuste
    # L'application ne détaille pas ses déductions CET1 poste par poste : elles
    # sont déclarées sur la seule ligne générique du formulaire.
    montants["FPI21"] = -deductions_cet1
    cet1 = max(cet1_ajuste - deductions_cet1, 0.0)
    montants["FPI22"] = cet1

    montants["FPI23"] = instruments_at1
    montants["FPI24"] = primes_at1
    montants["FPI25"] = 0.0
    montants["FPI26"] = instruments_at1 + primes_at1
    montants["FPI27"] = -deductions_at1
    at1 = max(instruments_at1 + primes_at1 - deductions_at1, 0.0)
    montants["FPI28"] = at1
    montants["FPI29"] = cet1 + at1

    montants["FPI30"] = dettes_t2
    montants["FPI35"] = provisions_t2
    montants["FPI39"] = dettes_t2 + provisions_t2
    t2 = max(dettes_t2 + provisions_t2 - deductions_t2, 0.0)
    montants["FPI40"] = t2
    montants["FPI41"] = cet1 + at1 + t2

    if deductions_at1:
        anomalies.append(convention(
            "Les déductions prudentielles AT1 sont déclarées sur la ligne FPI27 "
            "(ajustements réglementaires) : le formulaire n'offre pas de ligne "
            "générique pour cette catégorie."
        ))
    if deductions_t2:
        anomalies.append(convention(
            "Le formulaire n'offre aucune ligne de déduction générique en Tier 2 : "
            "les déductions T2 sont retranchées du total FPI40 sans apparaître "
            "sur une ligne détaillée."
        ))

    for code, montant in montants.items():
        _ecrire_montant(feuille, lignes.get(code, 0), COLONNE_C, montant)
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_C + 1))

    return (
        {
            "cet1": cet1,
            "at1": at1,
            "t1": cet1 + at1,
            "t2": t2,
            "total_capital": cet1 + at1 + t2,
        },
        anomalies,
    )


# ─── EP09 et EP10 : ventilation du bilan et du hors bilan ─────────────────


def _remplir_ep09(classeur, synthese: SyntheseCredit) -> None:
    feuille = classeur["EP09"]
    lignes = indexer_codes_dispru(feuille)
    valeurs: dict[str, dict[int, float]] = {}

    for categorie, code in LIGNES_EP09.items():
        bloc = synthese.bilan.get(categorie)
        valeurs[code] = {
            COLONNE_D: bloc.brut if bloc else 0.0,
            COLONNE_E: bloc.souffrance if bloc else 0.0,
            COLONNE_F: bloc.risque_eleve if bloc else 0.0,
            COLONNE_G: bloc.provisions if bloc else 0.0,
            COLONNE_H: bloc.deduit_fonds_propres if bloc else 0.0,
            COLONNE_I: bloc.net if bloc else 0.0,
        }

    _completer_lignes_agregees(valeurs, LIGNES_EP09_AGREGEES)
    _ajouter_ligne_totale(valeurs, LIGNE_TOTAL_EP09, LIGNES_TOTALISEES_EP09)

    for code, colonnes in valeurs.items():
        for colonne, montant in colonnes.items():
            _ecrire_montant(feuille, lignes.get(code, 0), colonne, montant)
    completer_a_zero(feuille, lignes, range(COLONNE_D, COLONNE_I + 1))


def _remplir_ep10(classeur, synthese: SyntheseCredit) -> None:
    feuille = classeur["EP10"]
    lignes = indexer_codes_dispru(feuille)
    colonnes_fcec = {
        palier: COLONNE_G + index for index, palier in enumerate(FCEC_FODEP)
    }
    colonne_apres_fcec = COLONNE_G + len(FCEC_FODEP)
    colonne_provisions = colonne_apres_fcec + 1
    colonne_net = colonne_provisions + 1

    valeurs: dict[str, dict[int, float]] = {}
    for categorie, code in LIGNES_EP10.items():
        bloc = synthese.hors_bilan.get(categorie)
        colonnes = {
            COLONNE_D: bloc.brut if bloc else 0.0,
            COLONNE_E: bloc.souffrance if bloc else 0.0,
            COLONNE_F: bloc.risque_eleve if bloc else 0.0,
            colonne_apres_fcec: bloc.brut_apres_fcec if bloc else 0.0,
            colonne_provisions: 0.0,
            colonne_net: bloc.net if bloc else 0.0,
        }
        for palier, colonne in colonnes_fcec.items():
            colonnes[colonne] = bloc.brut_par_fcec.get(palier, 0.0) if bloc else 0.0
        valeurs[code] = colonnes

    _completer_lignes_agregees(valeurs, LIGNES_EP10_AGREGEES)
    _ajouter_ligne_totale(valeurs, LIGNE_TOTAL_EP10, LIGNES_TOTALISEES_EP10)

    for code, colonnes in valeurs.items():
        for colonne, montant in colonnes.items():
            _ecrire_montant(feuille, lignes.get(code, 0), colonne, montant)
    # Le bloc des engagements de financement reste à zéro, faute de champ
    # distinguant leur nature dans l'application : la mise à zéro générale s'en
    # charge, en même temps que les colonnes non renseignées des autres lignes.
    completer_a_zero(feuille, lignes, range(COLONNE_D, colonne_net + 1))


def _completer_lignes_agregees(
    valeurs: dict[str, dict[int, float]],
    agregations: dict[str, tuple[str, ...]],
) -> None:
    """Renseigne les postes chapeaux (« dont : ») et leurs sous-postes vides."""

    for code_parent, codes_enfants in agregations.items():
        colonnes_parent: dict[int, float] = {}
        for code_enfant in codes_enfants:
            colonnes_enfant = valeurs.setdefault(code_enfant, {})
            for colonne, montant in colonnes_enfant.items():
                colonnes_parent[colonne] = colonnes_parent.get(colonne, 0.0) + montant
        # Un sous-poste sans montant reste une cellule à renseigner : le
        # formulaire n'admet pas de cellule de saisie laissée vide.
        for code_enfant in codes_enfants:
            colonnes_enfant = valeurs.setdefault(code_enfant, {})
            for colonne in colonnes_parent:
                colonnes_enfant.setdefault(colonne, 0.0)
        valeurs[code_parent] = colonnes_parent


def _ajouter_ligne_totale(
    valeurs: dict[str, dict[int, float]],
    code_total: str,
    codes_totalises: tuple[str, ...],
) -> None:
    total: dict[int, float] = {}
    for code in codes_totalises:
        for colonne, montant in valeurs.get(code, {}).items():
            total[colonne] = total.get(colonne, 0.0) + montant
    valeurs[code_total] = total


# ─── EP12 à EP19 : actifs pondérés par catégorie d'exposition ─────────────


def _paliers_par_categorie(classeur) -> dict[str, tuple[float, ...]]:
    paliers: dict[str, tuple[float, ...]] = {}
    for categorie, etat in ETAT_PAR_CATEGORIE.items():
        if categorie == agregation.CATEGORIE_AUTRES_ACTIFS:
            continue
        disposition = lire_disposition_categorie(classeur[etat])
        bloc = disposition.bloc(BLOC_BILAN)
        if bloc is not None:
            paliers[categorie] = bloc.ponderations
    return paliers


def _remplir_etats_categories(classeur, synthese: SyntheseCredit) -> dict[str, float]:
    """Renseigne les états EP12 à EP19 et retourne leur APR par catégorie."""

    apr_par_categorie: dict[str, float] = {}

    for categorie, etat in ETAT_PAR_CATEGORIE.items():
        if categorie == agregation.CATEGORIE_AUTRES_ACTIFS:
            continue
        feuille = classeur[etat]
        disposition = lire_disposition_categorie(feuille)
        blocs_donnees = {
            BLOC_BILAN: synthese.bilan.get(categorie),
            BLOC_ENGAGEMENT_FINANCEMENT: None,
            BLOC_AUTRES_HORS_BILAN: synthese.hors_bilan.get(categorie),
            BLOC_CONTREPARTIE: None,
        }
        apr_etat = 0.0
        totaux_generaux: dict[int, float] = {}

        for nom_bloc, bloc_disposition in disposition.blocs.items():
            donnees = blocs_donnees.get(nom_bloc)
            ventilation = donnees.ventilation if donnees is not None else None
            totaux_bloc: dict[int, float] = {}

            for ponderation, ligne in sorted(
                bloc_disposition.lignes_par_ponderation.items()
            ):
                avant_arc = garanties = ajustement = surete = 0.0
                if ventilation is not None:
                    avant_arc = ventilation.avant_arc.get(ponderation, 0.0)
                    garanties = ventilation.garanties.get(ponderation, 0.0)
                    ajustement = ventilation.ajustement_exposition.get(ponderation, 0.0)
                    surete = ventilation.surete_ajustee.get(ponderation, 0.0)
                apres_arc = avant_arc + garanties + ajustement + surete
                apr = apres_arc * ponderation

                colonnes = {
                    COLONNE_C: avant_arc,
                    COLONNE_D: garanties,
                    COLONNE_E: 0.0,
                    COLONNE_F: 0.0,
                    COLONNE_G: ajustement,
                    COLONNE_H: surete,
                    COLONNE_I: apres_arc,
                    COLONNE_J: apr,
                }
                for colonne, montant in colonnes.items():
                    _ecrire_montant(feuille, ligne, colonne, montant)
                    totaux_bloc[colonne] = totaux_bloc.get(colonne, 0.0) + montant

            for colonne, montant in totaux_bloc.items():
                _ecrire_montant(feuille, bloc_disposition.ligne_total, colonne, montant)
                totaux_generaux[colonne] = totaux_generaux.get(colonne, 0.0) + montant
            apr_etat += totaux_bloc.get(COLONNE_J, 0.0)

        for colonne, montant in totaux_generaux.items():
            _ecrire_montant(
                feuille, disposition.ligne_total_general, colonne, montant
            )
        # Les postes mémoire des expositions déclassées (EP16, EP17) ne sont
        # pas alimentés : l'application ne trace pas la catégorie d'origine.
        completer_a_zero(
            feuille, indexer_codes_dispru(feuille), range(COLONNE_C, COLONNE_J + 1)
        )
        apr_par_categorie[categorie] = apr_etat

    return apr_par_categorie


def _remplir_ep20(classeur, synthese: SyntheseCredit) -> float:
    """Renseigne l'état des autres actifs et retourne son APR."""

    feuille = classeur["EP20"]
    lignes = indexer_codes_dispru(feuille)
    total_exposition = 0.0
    total_apr = 0.0
    ligne_total = 0

    for code, ligne in lignes.items():
        libelle = feuille.cell(row=ligne, column=2).value
        if libelle and str(libelle).strip().upper().startswith("TOTAL"):
            ligne_total = ligne
            continue
        ponderation = flottant(feuille.cell(row=ligne, column=COLONNE_D).value)
        exposition = synthese.autres_actifs_par_ligne.get(code, 0.0)
        apr = exposition * ponderation
        _ecrire_montant(feuille, ligne, COLONNE_C, exposition)
        _ecrire_montant(feuille, ligne, COLONNE_E, apr)
        total_exposition += exposition
        total_apr += apr

    _ecrire_montant(feuille, ligne_total, COLONNE_C, total_exposition)
    _ecrire_montant(feuille, ligne_total, COLONNE_E, total_apr)
    return total_apr


# ─── EP21 : risque opérationnel, approche indicateur de base ──────────────


def _remplir_ep21(classeur) -> tuple[float, list[Reserve]]:
    """Renseigne l'approche indicateur de base et retourne l'APR opérationnel."""

    feuille = classeur["EP21"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    calcul = calcul_aib()
    parametres = get_aib_parametres()
    exercices = sorted(calcul.annees_saisies, key=lambda annee: annee.annee)[-3:]

    # Bloc A : l'application ne stocke que le produit brut annuel, sans son
    # détail comptable. Seule la ligne de total peut donc être renseignée.
    if exercices:
        _ecrire_montant(
            feuille, lignes.get("RO009", 0), COLONNE_D, exercices[-1].produit_brut_total
        )

    # Colonnes ANNÉE-3, ANNÉE-2 puis ANNÉE-1 : les exercices manquants sont
    # cadrés à gauche, l'exercice le plus récent restant en dernière colonne.
    ligne_apr = lignes.get("RO010", 0)
    produits_bruts = [0.0] * (3 - len(exercices)) + [
        exercice.pnb_retenu_aib for exercice in exercices
    ]
    for colonne, montant in zip((COLONNE_C, COLONNE_D, COLONNE_E), produits_bruts):
        _ecrire_montant(feuille, ligne_apr, colonne, montant)

    exigence = calcul.pnb_moyen * parametres.alpha
    apr = exigence * MULTIPLICATEUR_APR_FODEP

    _ecrire_montant(feuille, ligne_apr, COLONNE_F, calcul.pnb_moyen)
    _ecrire(feuille, ligne_apr, COLONNE_G, parametres.alpha)
    _ecrire_montant(feuille, ligne_apr, COLONNE_H, exigence)
    _ecrire_montant(feuille, ligne_apr, COLONNE_I, apr)

    if abs(calcul.apr_aib - apr) > 1.0:
        anomalies.append(convention(
            f"APR opérationnel : l'EP21 impose le multiplicateur "
            f"{MULTIPLICATEUR_APR_FODEP:.1f}, là où le module Risque "
            f"Opérationnel applique 1 / "
            f"{parametres.ratio_solvabilite_min:.0%}. L'APR déclaré "
            f"({apr:,.0f} FCFA) diffère donc de celui du tableau de bord "
            f"({calcul.apr_aib:,.0f} FCFA)."
        ))
    if calcul.donnees_insuffisantes:
        anomalies.append(a_verifier(
            "Aucun exercice de produit brut positif n'est enregistré : "
            "l'EP21 est déclaré à zéro."
        ))
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_I + 1))
    return apr, anomalies


# ─── EP22 : collecte des pertes opérationnelles ───────────────────────────

# Les sept catégories d'événements de Bâle, dans l'ordre du formulaire.
CODES_EP22: tuple[str, ...] = (
    "RO011",  # Fraude interne
    "RO012",  # Fraude externe
    "RO013",  # Pratiques en matière d'emploi et de sécurité au travail
    "RO014",  # Pratiques concernant les clients, les produits et l'activité
    "RO015",  # Dommages occasionnés aux actifs physiques
    "RO016",  # Interruptions d'activités et défaillances des systèmes
    "RO017",  # Exécution des opérations, livraisons et gestion des processus
)
CODE_TOTAL_EP22 = "RO018"

# L'application classe ses incidents par cause racine, taxonomie qui lui est
# propre et ne recouvre pas les sept catégories d'événements de Bâle. La
# correspondance ci-dessous est donc une convention, retenue faute de champ
# réglementaire à la saisie : seules les deux fraudes et la défaillance
# système se rattachent sans ambiguïté à une catégorie. Tout le reste est
# versé à l'exécution des opérations, catégorie résiduelle du dispositif.
#
# L'export le signale à chaque déclaration : une perte rangée dans la mauvaise
# catégorie est une erreur de déclaration, et le choix doit rester visible.
CATEGORIE_EP22_PAR_CAUSE: dict[str, str] = {
    "fraude interne": "RO011",
    "fraude externe": "RO012",
    "défaillance système": "RO016",
}
CATEGORIE_EP22_RESIDUELLE = "RO017"


def _exercice_declare(date_arrete: date) -> tuple[date, date]:
    """Bornes du dernier exercice clos à la date d'arrêté.

    La notice rattache les pertes de l'EP22 au « dernier exercice » : un
    arrêté au 31 décembre déclare son propre exercice, tout autre arrêté
    déclare l'exercice civil précédent, seul exercice clos à cette date.
    """

    annee = date_arrete.year if (date_arrete.month, date_arrete.day) == (12, 31) else date_arrete.year - 1
    return date(annee, 1, 1), date(annee, 12, 31)


def _lire_pertes_operationnelles() -> list[dict[str, Any]]:
    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT cause_racine, ligne_metier, perte_brute,
                   date_occurrence, date_comptabilisation
            FROM ro_incidents
            """
        ).fetchall()
    return [dict(ligne) for ligne in lignes]


def _date_de_comptabilisation(perte: dict[str, Any]) -> date | None:
    """Date de rattachement d'une perte, selon la notice.

    Le formulaire retient la première date de comptabilisation. L'application
    ne l'exige pas à la saisie : la date de survenance prend le relais quand
    elle manque, ce qui vaut mieux que d'écarter la perte.
    """

    for cle in ("date_comptabilisation", "date_occurrence"):
        valeur = str(perte.get(cle) or "").strip()
        if not valeur:
            continue
        try:
            return date.fromisoformat(valeur[:10])
        except ValueError:
            continue
    return None


def _remplir_ep22(classeur, date_arrete: date) -> list[Reserve]:
    """Renseigne la collecte des pertes opérationnelles du dernier exercice."""

    feuille = classeur["EP22"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    debut, fin = _exercice_declare(date_arrete)
    seuil = get_pertes_seuils().seuil_reporting_interne

    pertes: dict[str, list[float]] = {code: [] for code in CODES_EP22}
    deduites = 0
    sans_date = 0

    for perte in _lire_pertes_operationnelles():
        montant = flottant(perte.get("perte_brute"))
        if montant <= 0:
            continue
        jour = _date_de_comptabilisation(perte)
        if jour is None:
            sans_date += 1
            continue
        if not debut <= jour <= fin:
            continue
        cause = str(perte.get("cause_racine") or "").strip().casefold()
        code = CATEGORIE_EP22_PAR_CAUSE.get(cause)
        if code is None:
            code = CATEGORIE_EP22_RESIDUELLE
            deduites += 1
        pertes[code].append(montant)

    toutes: list[float] = []
    for code in CODES_EP22:
        montants = sorted(pertes[code], reverse=True)
        toutes.extend(montants)
        ligne = lignes.get(code, 0)
        _ecrire(feuille, ligne, COLONNE_C, len(montants))
        _ecrire_montant(feuille, ligne, COLONNE_D, sum(montants))
        _ecrire_montant(feuille, ligne, COLONNE_E, montants[0] if montants else 0.0)
        _ecrire_montant(feuille, ligne, COLONNE_F, sum(montants[:5]))
        # Le seuil de collecte n'est déclaré que là où une perte l'a été :
        # afficher un seuil sur une catégorie vide laisserait croire à une
        # collecte dont aucune perte n'est ressortie.
        if montants:
            _ecrire_montant(feuille, ligne, COLONNE_G, seuil)
            _ecrire_montant(feuille, ligne, COLONNE_H, seuil)

    toutes.sort(reverse=True)
    ligne_total = lignes.get(CODE_TOTAL_EP22, 0)
    _ecrire(feuille, ligne_total, COLONNE_C, len(toutes))
    _ecrire_montant(feuille, ligne_total, COLONNE_D, sum(toutes))
    _ecrire_montant(feuille, ligne_total, COLONNE_E, toutes[0] if toutes else 0.0)
    _ecrire_montant(feuille, ligne_total, COLONNE_F, sum(toutes[:5]))
    if toutes:
        _ecrire_montant(feuille, ligne_total, COLONNE_G, seuil)
        _ecrire_montant(feuille, ligne_total, COLONNE_H, seuil)

    periode = f"du {debut:%d/%m/%Y} au {fin:%d/%m/%Y}"
    if toutes:
        anomalies.append(information(
            f"EP22 : {len(toutes)} perte(s) brute(s) déclarée(s) pour l'exercice "
            f"{periode}, seuil de collecte {seuil:,.0f} FCFA."
        ))
    else:
        anomalies.append(a_verifier(
            f"EP22 : aucune perte comptabilisée sur l'exercice {periode}. "
            "L'état est déclaré à zéro — vérifiez que c'est bien le dernier "
            "exercice attendu par le formulaire."
        ))
    if deduites:
        anomalies.append(convention(
            f"EP22 : {deduites} perte(s) n'ont pas de cause racine se rattachant "
            "sans ambiguïté à une catégorie d'événement de Bâle et ont été "
            "versées à « Exécution des opérations ». Cette classification est "
            "une convention de l'application, pas une donnée déclarée : "
            "vérifiez-la avant transmission."
        ))
    if sans_date:
        anomalies.append(a_verifier(
            f"EP22 : {sans_date} perte(s) sans date exploitable ont été écartées."
        ))
    if seuil and en_millions(seuil) == 0:
        anomalies.append(information(
            f"EP22 : le seuil de collecte ({seuil:,.0f} FCFA) est inférieur au "
            "demi-million et s'arrondit donc à 0 dans l'unité du formulaire."
        ))

    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_H + 1))
    return anomalies


# ─── EP24 : pertes opérationnelles par ligne de métier ────────────────────

# Le formulaire croise les huit lignes de métier et les sept catégories
# d'événement : quatre mesures par ligne — nombre, montant total, perte
# maximale, total des cinq plus grandes — et une colonne par catégorie.
CODE_PREMIERE_LIGNE_EP24 = 38  # RO038, « Financement d'entreprise »
CODES_TOTAL_EP24 = ("RO070", "RO071", "RO072", "RO073")

# Colonnes des sept catégories d'événement, dans l'ordre de l'EP22, puis le
# total et les deux seuils de collecte.
COLONNE_PREMIERE_CATEGORIE_EP24 = 4
COLONNE_TOTAL_EP24 = 11
COLONNE_SEUIL_HAUT_EP24 = 12
COLONNE_SEUIL_BAS_EP24 = 13


def _mesures_de_pertes(montants: list[float]) -> tuple[int, float, float, float]:
    """Les quatre mesures que le formulaire demande d'un paquet de pertes."""

    tries = sorted(montants, reverse=True)
    return (
        len(tries),
        sum(tries),
        tries[0] if tries else 0.0,
        sum(tries[:5]),
    )


def _remplir_ep24(classeur, date_arrete: date) -> list[Reserve]:
    """Renseigne les pertes de l'exercice, ligne de métier par ligne de métier.

    Même collecte que l'EP22, croisée avec la ligne de métier que chaque
    incident porte déjà. La classification par catégorie d'événement reste
    celle de l'EP22 — la même convention, signalée de la même façon.
    """

    feuille = classeur["EP24"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    debut, fin = _exercice_declare(date_arrete)
    seuil = get_pertes_seuils().seuil_reporting_interne

    # (ligne de métier, catégorie) -> montants
    pertes: dict[tuple[int, str], list[float]] = {}
    hors_ligne_metier = 0
    index_par_metier = {
        metier.casefold(): index
        for index, (_, metier) in enumerate(LIGNES_METIER_EP23)
    }

    for perte in _lire_pertes_operationnelles():
        montant = flottant(perte.get("perte_brute"))
        if montant <= 0:
            continue
        jour = _date_de_comptabilisation(perte)
        if jour is None or not debut <= jour <= fin:
            continue
        metier = str(perte.get("ligne_metier") or "").strip().casefold()
        index = index_par_metier.get(metier)
        if index is None:
            hors_ligne_metier += 1
            continue
        cause = str(perte.get("cause_racine") or "").strip().casefold()
        code_categorie = CATEGORIE_EP22_PAR_CAUSE.get(cause, CATEGORIE_EP22_RESIDUELLE)
        pertes.setdefault((index, code_categorie), []).append(montant)

    def _ecrire_bloc(premier_code: str, colonne: int, montants: list[float]) -> None:
        rang = lignes.get(premier_code, 0)
        nombre, total, maximale, cinq = _mesures_de_pertes(montants)
        _ecrire(feuille, rang, colonne, nombre)
        _ecrire_montant(feuille, rang + 1, colonne, total)
        _ecrire_montant(feuille, rang + 2, colonne, maximale)
        _ecrire_montant(feuille, rang + 3, colonne, cinq)

    toutes: list[float] = []
    for index, (_, _metier) in enumerate(LIGNES_METIER_EP23):
        premier_code = f"RO{CODE_PREMIERE_LIGNE_EP24 + index * 4:03d}"
        de_la_ligne: list[float] = []
        for rang_categorie, code_categorie in enumerate(CODES_EP22):
            montants = pertes.get((index, code_categorie), [])
            de_la_ligne.extend(montants)
            _ecrire_bloc(
                premier_code,
                COLONNE_PREMIERE_CATEGORIE_EP24 + rang_categorie,
                montants,
            )
        _ecrire_bloc(premier_code, COLONNE_TOTAL_EP24, de_la_ligne)
        toutes.extend(de_la_ligne)
        if de_la_ligne:
            rang = lignes.get(premier_code, 0)
            for decalage in range(4):
                _ecrire_montant(
                    feuille, rang + decalage, COLONNE_SEUIL_HAUT_EP24, seuil
                )
                _ecrire_montant(
                    feuille, rang + decalage, COLONNE_SEUIL_BAS_EP24, seuil
                )

    # Ligne de total : par catégorie, puis toutes catégories confondues.
    rang_total = lignes.get(CODES_TOTAL_EP24[0], 0)
    for rang_categorie, code_categorie in enumerate(CODES_EP22):
        montants = [
            montant
            for (_, categorie), liste in pertes.items()
            if categorie == code_categorie
            for montant in liste
        ]
        _ecrire_bloc(
            CODES_TOTAL_EP24[0],
            COLONNE_PREMIERE_CATEGORIE_EP24 + rang_categorie,
            montants,
        )
    _ecrire_bloc(CODES_TOTAL_EP24[0], COLONNE_TOTAL_EP24, toutes)
    if toutes:
        for decalage in range(4):
            _ecrire_montant(
                feuille, rang_total + decalage, COLONNE_SEUIL_HAUT_EP24, seuil
            )
            _ecrire_montant(
                feuille, rang_total + decalage, COLONNE_SEUIL_BAS_EP24, seuil
            )

    if hors_ligne_metier:
        anomalies.append(a_verifier(
            f"EP24 : {hors_ligne_metier} perte(s) ne se rattachent à aucune des "
            "huit lignes de métier du formulaire et n'ont pas été déclarées. "
            "Renseignez leur ligne de métier au registre du risque opérationnel."
        ))
    if not toutes:
        anomalies.append(a_verifier(
            f"EP24 : aucune perte comptabilisée sur l'exercice du "
            f"{debut.strftime('%d/%m/%Y')} au {fin.strftime('%d/%m/%Y')}. "
            "L'état est déclaré à zéro."
        ))

    completer_a_zero(
        feuille, lignes, range(COLONNE_C, COLONNE_SEUIL_BAS_EP24 + 1)
    )
    return anomalies


# ─── EP23 : risque opérationnel, approche standard ────────────────────────

# Les huit lignes de métier, dans l'ordre où le formulaire range ses codes.
# Les libellés sont ceux du module Risque Opérationnel ; le rapprochement se
# fait sans tenir compte de la casse, le formulaire écrivant « Banque
# Commerciale » là où le module écrit « Banque commerciale ».
LIGNES_METIER_EP23: tuple[tuple[str, str], ...] = (
    ("RO027", "Financement d'entreprise"),
    ("RO028", "Activités de marché"),
    ("RO029", "Banque de détail"),
    ("RO030", "Banque commerciale"),
    ("RO031", "Paiements et règlements"),
    ("RO032", "Fonctions d'agent"),
    ("RO033", "Gestion d'actifs"),
    ("RO034", "Courtage de détail"),
)

# Bloc B : trois exercices, chacun sur deux colonnes — le produit brut, puis
# l'exigence qui en découle. L'exercice le plus récent occupe la dernière
# paire, comme dans l'EP21.
COLONNES_EXERCICES_EP23: tuple[tuple[int, int], ...] = (
    (COLONNE_D, COLONNE_E),
    (COLONNE_F, COLONNE_G),
    (COLONNE_H, COLONNE_I),
)

# Colonne « Total » du bloc A, à droite des huit lignes de métier.
COLONNE_TOTAL_EP23 = 11


def _remplir_ep23(classeur) -> tuple[float, list[Reserve]]:
    """Renseigne l'approche standard et retourne l'APR opérationnel.

    L'état est le jumeau de l'EP21 : là où l'approche indicateur de base
    applique un coefficient unique au produit brut total, l'approche standard
    le ventile en huit lignes de métier, chacune avec son bêta. Le module
    Risque Opérationnel tient déjà les deux — les bêtas réglementaires et le
    produit brut par ligne, exercice par exercice.

    L'exigence est la moyenne des trois derniers exercices, chacun plancher à
    zéro : c'est la règle de Bâle, et c'est ce que dit la ligne RO035 du
    formulaire, « total ou zéro, le plus élevé étant retenu ».
    """

    feuille = classeur["EP23"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    # Le calcul est celui du module Risque Opérationnel, pas un second : deux
    # implémentations de la même règle finiraient par diverger, et l'écran
    # contredirait la déclaration sur la même exigence.
    calcul = calcul_as()
    exercices = [detail for detail in calcul.detail_par_annee if detail.renseignee]

    # Bloc A : l'application ne stocke que le produit brut de chaque ligne, sans
    # son détail comptable. Seule la ligne de total peut donc être renseignée,
    # et pour le dernier exercice — le formulaire n'en présente qu'un.
    if exercices:
        produits = {
            ligne.ligne_metier.casefold(): ligne.pnb for ligne in exercices[-1].lignes
        }
        total_bloc_a = 0.0
        for index, (_, ligne_metier) in enumerate(LIGNES_METIER_EP23):
            montant = produits.get(ligne_metier.casefold(), 0.0)
            total_bloc_a += montant
            _ecrire_montant(
                feuille, lignes.get("RO026", 0), COLONNE_C + index, montant
            )
        _ecrire_montant(
            feuille, lignes.get("RO026", 0), COLONNE_TOTAL_EP23, total_bloc_a
        )

    # Bloc B : les exercices manquants sont cadrés à gauche, le plus récent
    # restant dans la dernière paire de colonnes.
    decalage = 3 - len(exercices)
    for rang_exercice, exercice in enumerate(exercices):
        par_ligne = {
            ligne.ligne_metier.casefold(): ligne for ligne in exercice.lignes
        }
        colonne_brut, colonne_exigence = COLONNES_EXERCICES_EP23[rang_exercice + decalage]
        total_brut = 0.0
        for code, ligne_metier in LIGNES_METIER_EP23:
            detail = par_ligne.get(ligne_metier.casefold())
            brut = detail.pnb if detail else 0.0
            total_brut += brut
            _ecrire_montant(feuille, lignes.get(code, 0), colonne_brut, brut)
            _ecrire_montant(
                feuille,
                lignes.get(code, 0),
                colonne_exigence,
                detail.k_ligne if detail else 0.0,
            )
        # « Total ou zéro, le plus élevé étant retenu » : un exercice à produit
        # brut négatif ne réduit pas l'exigence des autres.
        _ecrire_montant(feuille, lignes.get("RO035", 0), colonne_brut, total_brut)
        _ecrire_montant(
            feuille, lignes.get("RO035", 0), colonne_exigence, exercice.k_retenu
        )

    apr = calcul.k_as * MULTIPLICATEUR_APR_FODEP
    _ecrire_montant(feuille, lignes.get("RO036", 0), COLONNE_I, calcul.k_as)
    _ecrire_montant(feuille, lignes.get("RO037", 0), COLONNE_I, apr)

    if not exercices:
        anomalies.append(a_verifier(
            "EP23 : aucun produit brut par ligne de métier n'est enregistré. "
            "L'approche standard est déclarée à zéro alors qu'elle est la "
            "méthode retenue — renseignez les lignes de métier sur l'écran "
            "Risque opérationnel."
        ))
    elif len(exercices) < 3:
        anomalies.append(a_verifier(
            f"EP23 : l'exigence est la moyenne des trois derniers exercices ; "
            f"{len(exercices)} seulement {'est enregistré' if len(exercices) == 1 else 'sont enregistrés'} "
            f"({', '.join(str(exercice.annee) for exercice in exercices)}). Le montant "
            "déclaré porte donc sur ce qui est disponible."
        ))

    anomalies.append(convention(
        "EP23 : le détail comptable du produit brut (produit d'exploitation "
        "bancaire, charges, plus et moins-values) n'est pas suivi par "
        "l'application. Seule la ligne de total du bloc A est renseignée, à "
        "partir du produit brut saisi pour chaque ligne de métier."
    ))

    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_TOTAL_EP23 + 1))
    return apr, anomalies


# ─── EP08 et EP02 : totaux et ratios ──────────────────────────────────────


def repartir_en_millions(total_fcfa: float, parts: dict[str, float]) -> dict[str, int]:
    """Ventile un total en millions de FCFA sans que les arrondis ne le trahissent.

    Arrondir chaque part séparément ferait diverger leur somme du total de
    quelques millions — un écart qu'un contrôleur relève à juste titre sur un
    état qui doit se boucler. Les millions perdus par l'arrondi sont donc
    réattribués aux parts dont la décimale était la plus forte, de sorte que
    la somme des lignes de détail égale exactement le total déclaré.
    """

    total_millions = en_millions(total_fcfa)
    somme_parts = sum(parts.values())
    if somme_parts <= 0:
        return {nature: 0 for nature in parts}

    exactes = {
        nature: total_millions * valeur / somme_parts for nature, valeur in parts.items()
    }
    repartition = {nature: int(valeur) for nature, valeur in exactes.items()}
    reste = total_millions - sum(repartition.values())

    ordre = sorted(
        exactes,
        key=lambda nature: (exactes[nature] - int(exactes[nature])),
        reverse=True,
    )
    for index in range(reste):
        repartition[ordre[index % len(ordre)]] += 1
    return repartition


def _remplir_ep08(
    classeur,
    apr_par_categorie: dict[str, float],
    apr_autres_actifs: float,
    apr_marche: float,
    apr_operationnel: float,
    ventilation_marche: dict[str, float] | None = None,
    approche_standard: bool = False,
) -> float:
    feuille = classeur["EP08"]
    lignes = indexer_codes_dispru(feuille)

    codes_par_categorie = {
        "a": "RC089",
        "b": "RC114",
        "c": "RC139",
        "d": "RC164",
        "e": "RC193",
        "f": "RC219",
        "g": "RC239",
        "h": "RC261",
    }
    apr_credit = apr_autres_actifs
    for categorie, code in codes_par_categorie.items():
        montant = apr_par_categorie.get(categorie, 0.0)
        _ecrire_montant(feuille, lignes.get(code, 0), COLONNE_E, montant)
        apr_credit += montant
    _ecrire_montant(feuille, lignes.get("RC276", 0), COLONNE_E, apr_autres_actifs)
    _ecrire_montant(feuille, lignes.get("APR01", 0), COLONNE_E, apr_credit)

    # Les quatre natures de risque de marché, dans l'ordre du formulaire.
    codes_par_nature = {
        "taux": "RM044",
        "actions": "RM057",
        "change": "RM067",
        "produits_de_base": "RM123",
    }
    if ventilation_marche:
        # Le module Risque de Marché raisonne en exigence de fonds propres ;
        # l'EP08 attend des actifs pondérés. La conversion étant le même
        # multiplicateur pour les quatre natures, répartir l'APR total au
        # prorata des exigences revient au même — sans risquer que les lignes
        # ne totalisent plus l'APR02 à cause des arrondis.
        detail = repartir_en_millions(apr_marche, ventilation_marche)
        for nature, code in codes_par_nature.items():
            _ecrire(feuille, lignes.get(code, 0), COLONNE_E, detail.get(nature, 0))
    else:
        for code in codes_par_nature.values():
            _ecrire_montant(feuille, lignes.get(code, 0), COLONNE_E, 0.0)
    _ecrire_montant(feuille, lignes.get("APR02", 0), COLONNE_E, apr_marche)

    # L'APR opérationnel se porte sur la ligne de l'approche retenue, et l'autre
    # reste à zéro : un établissement applique une méthode, pas les deux.
    ligne_methode = "RO037" if approche_standard else "RO010"
    ligne_ecartee = "RO010" if approche_standard else "RO037"
    _ecrire_montant(feuille, lignes.get(ligne_methode, 0), COLONNE_E, apr_operationnel)
    _ecrire_montant(feuille, lignes.get(ligne_ecartee, 0), COLONNE_E, 0.0)
    _ecrire_montant(feuille, lignes.get("APR03", 0), COLONNE_E, apr_operationnel)

    total = apr_credit + apr_marche + apr_operationnel
    _ecrire_montant(feuille, lignes.get("APR04", 0), COLONNE_E, total)
    completer_a_zero(feuille, lignes, range(COLONNE_E, COLONNE_E + 1))
    return total


def _remplir_ep02(classeur, fonds_propres: dict[str, float], apr_total: float) -> None:
    feuille = classeur["EP02"]
    lignes = indexer_codes_dispru(feuille)
    colonne = COLONNE_F

    def ratio(numerateur: float) -> float:
        return round(numerateur / apr_total, 4) if apr_total > 0 else 0.0

    _ecrire(feuille, lignes.get("RA001", 0), colonne, ratio(fonds_propres["cet1"]))
    _ecrire(feuille, lignes.get("RA002", 0), colonne, ratio(fonds_propres["t1"]))
    _ecrire(
        feuille, lignes.get("RA003", 0), colonne, ratio(fonds_propres["total_capital"])
    )
    _ecrire_montant(
        feuille, lignes.get("FPI22 / FPC22", 0), colonne, fonds_propres["cet1"]
    )
    _ecrire_montant(
        feuille, lignes.get("FPI29 / FPC29", 0), colonne, fonds_propres["t1"]
    )
    _ecrire_montant(
        feuille, lignes.get("FPI41 / FPC41", 0), colonne, fonds_propres["total_capital"]
    )
    _ecrire_montant(feuille, lignes.get("APR04", 0), colonne, apr_total)


# ─── EP29 et EP33 : division des risques et ratio de levier ───────────────


def _agreger_par_contrepartie(
    expositions: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    """Regroupe les expositions par contrepartie, pour les états EP29 à EP32.

    Les quatre états de la division des risques décrivent la même population
    sous quatre angles : les grands risques, leur détail, leurs échéances et
    les cinquante plus gros engagements. Les agréger une fois garantit qu'ils
    racontent la même histoire.
    """

    groupes: dict[str, dict[str, Any]] = {}
    for exposition in expositions:
        nom = str(exposition.get("counterparty_name") or "").strip()
        if not nom:
            continue
        devise = str(exposition.get("currency") or DEVISE_DECLARATION)

        def en_xof(valeur: Any) -> float:
            return convert_currency_amount(
                flottant(valeur),
                from_currency=devise,
                to_currency=DEVISE_DECLARATION,
            )

        groupe = groupes.setdefault(
            nom,
            {
                "pays": str(exposition.get("country") or ""),
                "secteur": str(exposition.get("category_raw") or ""),
                "bilan": 0.0,
                "hors_bilan": 0.0,
                "souffrance": 0.0,
                "provisions": 0.0,
                "encours_brut": 0.0,
                "apr": 0.0,
                "echeances": defaultdict(float),
                "hors_division": True,
                "contrepartie": False,
            },
        )
        bilan = en_xof(exposition.get("ead_bilan_amount"))
        hors_bilan = en_xof(exposition.get("ead_hb_ccf_amount"))
        groupe["bilan"] += bilan
        groupe["hors_bilan"] += hors_bilan
        groupe["provisions"] += en_xof(exposition.get("provisions_amount"))
        groupe["encours_brut"] += en_xof(
            exposition.get("on_balance_exposure_amount")
            if exposition.get("on_balance_exposure_amount") is not None
            else exposition.get("gross_amount")
        )
        groupe["apr"] += en_xof(exposition.get("rwa"))
        groupe["echeances"][
            _tranche_echeance(exposition.get("residual_maturity_months"))
        ] += bilan + hors_bilan
        if str(exposition.get("prudential_type") or "").lower() == "i":
            groupe["souffrance"] += bilan + hors_bilan

        categorie = categorie_fodep(exposition)
        # La division des risques ne vise que les risques portés sur une
        # contrepartie : ni les expositions souveraines, ni les postes de
        # bilan rangés en « autres actifs » (encaisse, immobilisations) n'y
        # entrent. Une contrepartie n'est écartée que si toutes ses lignes
        # relèvent de ces catégories.
        if categorie not in CATEGORIES_HORS_DIVISION:
            groupe["hors_division"] = False
        if categorie != agregation.CATEGORIE_AUTRES_ACTIFS:
            groupe["contrepartie"] = True

    return groupes


def _exposition_totale(agrege: dict[str, Any]) -> float:
    return agrege["bilan"] + agrege["hors_bilan"]


def _contreparties_par_exposition(
    groupes: dict[str, dict[str, Any]], *, division_des_risques: bool = True
) -> list[tuple[str, dict[str, Any]]]:
    """Contreparties triées par exposition décroissante.

    `division_des_risques` restreint au périmètre des états EP29 à EP31, qui
    laissent de côté les souverains et les postes de bilan sans contrepartie.
    L'EP32, qui recense des engagements et non des risques pondérés, retient
    en revanche toute contrepartie.
    """

    def retenu(agrege: dict[str, Any]) -> bool:
        if division_des_risques:
            return not agrege["hors_division"]
        return bool(agrege["contrepartie"])

    retenus = [(nom, agrege) for nom, agrege in groupes.items() if retenu(agrege)]
    retenus.sort(key=lambda item: _exposition_totale(item[1]), reverse=True)
    return retenus


def _grands_risques(
    groupes: dict[str, dict[str, Any]], fonds_propres_t1: float
) -> list[tuple[str, dict[str, Any]]]:
    """Contreparties dont l'exposition atteint le seuil des grands risques."""

    seuil = fonds_propres_t1 * SEUIL_GRAND_RISQUE
    if seuil <= 0:
        return []
    return [
        (nom, agrege)
        for nom, agrege in _contreparties_par_exposition(groupes)
        if _exposition_totale(agrege) >= seuil
    ]


def _remplir_ep29(
    classeur,
    groupes: dict[str, dict[str, Any]],
    fonds_propres_t1: float,
) -> float:
    """Déclare les grands risques et retourne le plus élevé des ratios APR/T1."""

    feuille = classeur["EP29"]
    lignes = indexer_codes_dispru(feuille)
    grands_risques = _grands_risques(groupes, fonds_propres_t1)

    codes_declaration = [f"GR{index:03d}" for index in range(1, 52)]
    ligne_total = lignes.get(codes_declaration[-1], 0)
    colonne_nom, colonne_pays, colonne_secteur = COLONNE_D, COLONNE_E, COLONNE_F
    colonne_totale, colonne_souffrance = COLONNE_G, COLONNE_H
    colonne_bilan = COLONNE_I
    colonne_autres_engagements = 14

    totaux = {colonne: 0.0 for colonne in (colonne_totale, colonne_souffrance, colonne_bilan, colonne_autres_engagements)}
    for index, code in enumerate(codes_declaration[:-1]):
        ligne = lignes.get(code, 0)
        if index >= len(grands_risques):
            continue
        nom, agrege = grands_risques[index]
        exposition_totale = _exposition_totale(agrege)
        _ecrire(feuille, ligne, colonne_nom, nom)
        _ecrire(feuille, ligne, colonne_pays, agrege["pays"])
        _ecrire(feuille, ligne, colonne_secteur, agrege["secteur"])
        _ecrire_montant(feuille, ligne, colonne_totale, exposition_totale)
        _ecrire_montant(feuille, ligne, colonne_souffrance, agrege["souffrance"])
        _ecrire_montant(feuille, ligne, colonne_bilan, agrege["bilan"])
        _ecrire_montant(feuille, ligne, colonne_autres_engagements, agrege["hors_bilan"])
        totaux[colonne_totale] += exposition_totale
        totaux[colonne_souffrance] += agrege["souffrance"]
        totaux[colonne_bilan] += agrege["bilan"]
        totaux[colonne_autres_engagements] += agrege["hors_bilan"]

    for colonne, montant in totaux.items():
        _ecrire_montant(feuille, ligne_total, colonne, montant)

    # Poste mémoire : actifs pondérés de chaque grand risque, rapportés aux
    # fonds propres de base. C'est ce rapport que l'EP01 confronte à la norme.
    ratio_maximal = 0.0
    codes_memoire = [f"GR{index:03d}" for index in range(52, 72)]
    for index, code in enumerate(codes_memoire):
        ligne = lignes.get(code, 0)
        if index >= len(grands_risques):
            continue
        nom, agrege = grands_risques[index]
        rapport = agrege["apr"] / fonds_propres_t1 if fonds_propres_t1 > 0 else 0.0
        _ecrire(feuille, ligne, COLONNE_D, nom)
        _ecrire_montant(feuille, ligne, COLONNE_E, agrege["apr"])
        _ecrire(feuille, ligne, COLONNE_F, round(rapport, 4))
        ratio_maximal = max(ratio_maximal, rapport)

    completer_a_zero(feuille, lignes, range(colonne_totale, colonne_autres_engagements + 1))
    return ratio_maximal


def _tranche_echeance(mois_restants: Any) -> int:
    """Indice de la tranche d'échéance de l'EP31, la dernière valant « non définie ».

    Les tranches sont mensuelles jusqu'à un an, trimestrielles jusqu'à trois
    ans, puis s'élargissent. Une échéance inconnue a sa propre colonne : la
    ranger d'office dans la plus longue laisserait croire à un engagement à
    plus de dix ans.
    """

    if mois_restants is None:
        return len(BORNES_ECHEANCE_EP31) + 1
    mois = flottant(mois_restants)
    for index, borne in enumerate(BORNES_ECHEANCE_EP31):
        if mois <= borne:
            return index
    return len(BORNES_ECHEANCE_EP31)


def _remplir_ep31(classeur, groupes: dict[str, dict[str, Any]]) -> None:
    """Ventile les vingt plus grandes expositions par catégorie d'échéance.

    L'état ne retient pas le seuil des grands risques : il déclare les vingt
    premières expositions quel qu'en soit le montant, contrairement à l'EP29.
    """

    feuille = classeur["EP31"]
    lignes = indexer_codes_dispru(feuille)
    colonne_nom = COLONNE_C
    premiere_tranche = COLONNE_D
    nombre_de_tranches = len(BORNES_ECHEANCE_EP31) + 2
    colonne_total = premiere_tranche + nombre_de_tranches

    codes = [f"GR{index:03d}" for index in range(173, 194)]
    plus_grands = _contreparties_par_exposition(groupes)[: len(codes) - 1]
    totaux: dict[int, float] = defaultdict(float)

    for index, code in enumerate(codes[:-1]):
        ligne = lignes.get(code, 0)
        if index >= len(plus_grands):
            continue
        nom, agrege = plus_grands[index]
        _ecrire(feuille, ligne, colonne_nom, nom)
        for tranche, montant in agrege["echeances"].items():
            _ecrire_montant(feuille, ligne, premiere_tranche + tranche, montant)
            totaux[tranche] += montant
        _ecrire_montant(feuille, ligne, colonne_total, _exposition_totale(agrege))
        totaux[colonne_total] += _exposition_totale(agrege)

    ligne_total = lignes.get(codes[-1], 0)
    for tranche in range(nombre_de_tranches):
        _ecrire_montant(feuille, ligne_total, premiere_tranche + tranche, totaux[tranche])
    _ecrire_montant(feuille, ligne_total, colonne_total, totaux[colonne_total])
    completer_a_zero(feuille, lignes, range(premiere_tranche, colonne_total + 1))


def _remplir_ep32(classeur, groupes: dict[str, dict[str, Any]]) -> None:
    """Déclare les cinquante plus gros engagements."""

    feuille = classeur["EP32"]
    lignes = indexer_codes_dispru(feuille)
    colonne_nom, colonne_pays, colonne_secteur = COLONNE_C, COLONNE_D, COLONNE_E
    colonne_brut, colonne_provisions = COLONNE_F, COLONNE_G
    colonne_net, colonne_hors_bilan, colonne_total = COLONNE_H, COLONNE_I, COLONNE_J

    codes = [f"GR{index:03d}" for index in range(194, 245)]
    engagements = _contreparties_par_exposition(
        groupes, division_des_risques=False
    )[: len(codes) - 1]

    totaux: dict[int, float] = defaultdict(float)
    for index, code in enumerate(codes[:-1]):
        ligne = lignes.get(code, 0)
        if index >= len(engagements):
            continue
        nom, agrege = engagements[index]
        colonnes = {
            colonne_brut: agrege["encours_brut"],
            colonne_provisions: agrege["provisions"],
            colonne_net: agrege["bilan"],
            colonne_hors_bilan: agrege["hors_bilan"],
            colonne_total: _exposition_totale(agrege),
        }
        _ecrire(feuille, ligne, colonne_nom, nom)
        _ecrire(feuille, ligne, colonne_pays, agrege["pays"])
        _ecrire(feuille, ligne, colonne_secteur, agrege["secteur"])
        for colonne, montant in colonnes.items():
            _ecrire_montant(feuille, ligne, colonne, montant)
            totaux[colonne] += montant

    ligne_total = lignes.get(codes[-1], 0)
    for colonne in (
        colonne_brut, colonne_provisions, colonne_net,
        colonne_hors_bilan, colonne_total,
    ):
        _ecrire_montant(feuille, ligne_total, colonne, totaux[colonne])
    completer_a_zero(feuille, lignes, range(colonne_brut, colonne_total + 1))


def _remplir_ep33(
    classeur,
    synthese: SyntheseCredit,
    fonds_propres_t1: float,
) -> float:
    """Renseigne le ratio de levier et le retourne."""

    feuille = classeur["EP33"]
    lignes = indexer_codes_dispru(feuille)

    actifs_bilan = sum(bloc.net for bloc in synthese.bilan.values())
    engagements_hors_bilan = sum(bloc.net for bloc in synthese.hors_bilan.values())

    _ecrire_montant(feuille, lignes.get("RL001", 0), COLONNE_C, actifs_bilan)
    _ecrire_montant(feuille, lignes.get("RL002", 0), COLONNE_C, 0.0)
    _ecrire_montant(feuille, lignes.get("RL003", 0), COLONNE_C, 0.0)
    _ecrire_montant(feuille, lignes.get("RL004", 0), COLONNE_C, actifs_bilan)
    for code in ("RL005", "RL006", "RL007", "RL008", "RL009", "RL010", "RL011"):
        _ecrire_montant(feuille, lignes.get(code, 0), COLONNE_C, 0.0)
    _ecrire_montant(feuille, lignes.get("RL012", 0), COLONNE_C, engagements_hors_bilan)
    _ecrire_montant(feuille, lignes.get("RL013", 0), COLONNE_C, engagements_hors_bilan)

    exposition_totale = actifs_bilan + engagements_hors_bilan
    ratio = fonds_propres_t1 / exposition_totale if exposition_totale > 0 else 0.0
    _ecrire_montant(feuille, lignes.get("RL014", 0), COLONNE_C, fonds_propres_t1)
    _ecrire_montant(feuille, lignes.get("RL015", 0), COLONNE_C, exposition_totale)
    _ecrire(feuille, lignes.get("RA005", 0), COLONNE_C, round(ratio, 4))
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_C + 1))
    return ratio


# ─── EP25 : détail du risque de taux d'intérêt ────────────────────────────

# Traduction de la taxonomie du module Risque de Marché vers les lignes du
# formulaire. Le module raisonne en catégorie d'émetteur, qualité de signature
# et tranche de maturité ; l'EP25 combine les trois sur quatorze lignes. La
# correspondance appartient à l'export : le calcul n'a pas à connaître les
# codes DISPRU.
#
# Clé : (catégorie, qualité, tranche). La tranche ne discrimine que les
# souverains A+/BBB- et les titres éligibles ; ailleurs elle est ignorée.
LIGNES_EP25_SPECIFIQUE: dict[tuple[str, str, str], str] = {
    # Titres d'États de l'UMOA libellés et financés en FCFA : pondération nulle.
    **{
        ("uemoaSovereignXof", qualite, tranche): "RM002"
        for qualite in ("aaaToAa", "aToBbb", "bbToB", "belowB", "unrated")
        for tranche in ("court", "moyen", "long")
    },
    # Autres souverains, par qualité de signature.
    **{
        ("sovereignDebt", "aaaToAa", tranche): "RM001"
        for tranche in ("court", "moyen", "long")
    },
    ("sovereignDebt", "aToBbb", "court"): "RM003",
    ("sovereignDebt", "aToBbb", "moyen"): "RM004",
    ("sovereignDebt", "aToBbb", "long"): "RM005",
    **{
        ("sovereignDebt", "bbToB", tranche): "RM006"
        for tranche in ("court", "moyen", "long")
    },
    **{
        ("sovereignDebt", "belowB", tranche): "RM007"
        for tranche in ("court", "moyen", "long")
    },
    **{
        ("sovereignDebt", "unrated", tranche): "RM008"
        for tranche in ("court", "moyen", "long")
    },
    # Titres éligibles : seule la durée résiduelle les distingue.
    **{
        ("eligibleDebt", qualite, "court"): "RM009"
        for qualite in ("aaaToAa", "aToBbb", "bbToB", "belowB", "unrated")
    },
    **{
        ("eligibleDebt", qualite, "moyen"): "RM010"
        for qualite in ("aaaToAa", "aToBbb", "bbToB", "belowB", "unrated")
    },
    **{
        ("eligibleDebt", qualite, "long"): "RM011"
        for qualite in ("aaaToAa", "aToBbb", "bbToB", "belowB", "unrated")
    },
    # Autres émetteurs.
    **{
        ("otherDebt", qualite, tranche): "RM012"
        for qualite in ("aaaToAa", "aToBbb", "bbToB")
        for tranche in ("court", "moyen", "long")
    },
    **{
        ("otherDebt", "belowB", tranche): "RM013"
        for tranche in ("court", "moyen", "long")
    },
    **{
        ("otherDebt", "unrated", tranche): "RM014"
        for tranche in ("court", "moyen", "long")
    },
}

# Tranches d'échéance du risque général, dans l'ordre des compartiments que le
# module numérote de 0 à 12. Les deux dernières lignes du formulaire (RM029 et
# RM030) visent les coupons inférieurs à 3 %, que le module range déjà dans
# les tranches standard : elles restent à zéro.
LIGNES_EP25_TRANCHES: tuple[str, ...] = (
    "RM016", "RM017", "RM018", "RM019",
    "RM020", "RM021", "RM022", "RM023",
    "RM024", "RM025", "RM026", "RM027", "RM028",
)
CODES_ZONES_EP25: dict[int, str] = {1: "RM125", 2: "RM126", 3: "RM127"}

# Lignes de compensation, avec la clé que le module transmet pour chacune. Le
# facteur est imprimé par le formulaire, jamais recalculé ici.
LIGNES_EP25_COMPENSATION: tuple[tuple[str, str], ...] = (
    ("RM031", "equilibre_toutes_tranches"),
    ("RM032", "equilibre_plage_1"),
    ("RM033", "equilibre_plage_2"),
    ("RM034", "equilibre_plage_3"),
    ("RM035", "equilibre_plages_1_2"),
    ("RM036", "equilibre_plages_2_3"),
    ("RM037", "equilibre_plages_1_3"),
    ("RM038", "residu"),
)


def _remplir_ep25(classeur, positions: dict[str, Any] | None) -> list[Reserve]:
    """Déclare l'échelle de maturité du risque de taux.

    Le formulaire reprend l'approche standard dans son entier : le risque
    spécifique par catégorie d'émetteur, puis l'échelle de maturité et ses
    compensations successives — par tranche, par plage, entre plages, et le
    résidu. Le module calcule déjà tout cela pour établir son exigence.
    """

    feuille = classeur["EP25"]
    lignes = indexer_codes_dispru(feuille)
    taux = (positions or {}).get("taux")
    if not isinstance(taux, dict):
        return []

    anomalies: list[Reserve] = []

    # ── Section A : risque spécifique ──────────────────────────────────────
    cumuls: dict[str, dict[str, float]] = {}
    non_classees = 0
    for ligne_source in taux.get("specifique") or []:
        cle = (
            str(ligne_source.get("categorie") or ""),
            str(ligne_source.get("qualite") or ""),
            str(ligne_source.get("tranche") or ""),
        )
        code = LIGNES_EP25_SPECIFIQUE.get(cle)
        if code is None:
            non_classees += 1
            continue
        cumul = cumuls.setdefault(code, {"longues": 0.0, "courtes": 0.0})
        cumul["longues"] += flottant(ligne_source.get("longues"))
        cumul["courtes"] += flottant(ligne_source.get("courtes"))

    exigence_specifique = 0.0
    for code, cumul in cumuls.items():
        ligne = lignes.get(code, 0)
        if not ligne:
            continue
        longues, courtes = cumul["longues"], cumul["courtes"]
        # Le risque spécifique ne compense pas les sens : son assiette est la
        # somme des positions en valeur absolue.
        assiette = longues + courtes
        _ecrire_montant(feuille, ligne, COLONNE_C, longues)
        _ecrire_montant(feuille, ligne, COLONNE_D, courtes)
        _ecrire_montant(feuille, ligne, COLONNE_E, longues)
        _ecrire_montant(feuille, ligne, COLONNE_F, courtes)
        _ecrire_montant(feuille, ligne, COLONNE_G, assiette)
        exigence = assiette * _ponderation(feuille, ligne, COLONNE_H)
        _ecrire_montant(feuille, ligne, COLONNE_I, exigence)
        exigence_specifique += exigence
    _ecrire_montant(feuille, lignes.get("RM015", 0), COLONNE_I, exigence_specifique)

    if non_classees:
        anomalies.append(a_verifier(
            f"EP25 : {non_classees} agrégat(s) de titres n'ont pas trouvé de "
            "ligne dans le formulaire et n'ont pas été déclarés au risque "
            "spécifique."
        ))

    # ── Section B : échelle de maturité ────────────────────────────────────
    general = taux.get("general")
    if not isinstance(general, dict):
        return anomalies

    par_zone: dict[int, list[float]] = {1: [0.0, 0.0], 2: [0.0, 0.0], 3: [0.0, 0.0]}
    for tranche in general.get("tranches") or []:
        index = int(flottant(tranche.get("index")))
        if not 0 <= index < len(LIGNES_EP25_TRANCHES):
            continue
        longues = flottant(tranche.get("nettes_longues"))
        courtes = flottant(tranche.get("nettes_courtes"))
        ligne = lignes.get(LIGNES_EP25_TRANCHES[index], 0)
        _ecrire_montant(feuille, ligne, COLONNE_E, longues)
        _ecrire_montant(feuille, ligne, COLONNE_F, courtes)
        zone = int(flottant(tranche.get("zone"))) or 1
        if zone in par_zone:
            par_zone[zone][0] += longues
            par_zone[zone][1] += courtes

    # Les en-têtes de zone portent le cumul des positions de leur plage.
    for zone, code in CODES_ZONES_EP25.items():
        ligne = lignes.get(code, 0)
        _ecrire_montant(feuille, ligne, COLONNE_C, par_zone[zone][0])
        _ecrire_montant(feuille, ligne, COLONNE_D, par_zone[zone][1])

    exigence_generale = 0.0
    for code, cle in LIGNES_EP25_COMPENSATION:
        ligne = lignes.get(code, 0)
        if not ligne:
            continue
        equilibre = flottant(general.get(cle))
        _ecrire_montant(feuille, ligne, COLONNE_G, equilibre)
        exigence = equilibre * _ponderation(feuille, ligne, COLONNE_H)
        _ecrire_montant(feuille, ligne, COLONNE_I, exigence)
        exigence_generale += exigence
    _ecrire_montant(feuille, lignes.get("RM039", 0), COLONNE_I, exigence_generale)

    anomalies.append(convention(
        "EP25 : le module tient une échelle de maturité par devise, là où le "
        "formulaire n'en présente qu'une. Les tranches déclarées sont donc la "
        "somme des échelles, tandis que l'exigence reste calculée devise par "
        "devise — c'est elle qui fait foi."
    ))
    return anomalies


# ─── EP26 et EP27 : détail du risque de marché ────────────────────────────

# Pondérations imposées par le formulaire, relues plutôt que codées : la
# colonne les porte, verrouillée, et c'est elle qui fait foi. Les redéclarer
# ici exposerait à ce qu'un jour l'exigence ne vaille plus la position
# multipliée par sa pondération.
COLONNE_PONDERATION_EP26 = COLONNE_H
COLONNE_EXIGENCE_EP26 = COLONNE_I
COLONNE_PONDERATION_EP27 = COLONNE_I
COLONNE_EXIGENCE_EP27 = COLONNE_J


def _ponderation(feuille, ligne: int, colonne: int) -> float:
    """Lit la pondération que le formulaire impose sur une ligne."""

    return flottant(feuille.cell(row=ligne, column=colonne).value)


def _remplir_ep26(classeur, positions: dict[str, Any] | None) -> list[Reserve]:
    """Détaille le risque de position sur titres de propriété.

    Le formulaire distingue trois assiettes par ligne : toutes les positions,
    les positions nettes, puis celles réellement soumises à l'exigence. Les
    deux premières décrivent le portefeuille, la troisième porte le calcul.
    """

    feuille = classeur["EP26"]
    lignes = indexer_codes_dispru(feuille)
    actions = (positions or {}).get("actions")
    if not isinstance(actions, dict):
        return []

    longues = flottant(actions.get("longues"))
    courtes = flottant(actions.get("courtes"))
    nettes_longues = flottant(actions.get("nettes_longues"))
    nettes_courtes = flottant(actions.get("nettes_courtes"))
    base_liquide = flottant(actions.get("base_specifique_liquide"))
    base_autre = flottant(actions.get("base_specifique_autre"))
    base_generale = flottant(actions.get("base_generale"))

    def ecrire_ligne(code: str, assiette: float, colonne_ponderation: int) -> float:
        """Renseigne une ligne et retourne l'exigence qu'elle déclare."""

        ligne = lignes.get(code, 0)
        if not ligne:
            return 0.0
        _ecrire_montant(feuille, ligne, COLONNE_C, longues)
        _ecrire_montant(feuille, ligne, COLONNE_D, courtes)
        _ecrire_montant(feuille, ligne, COLONNE_E, nettes_longues)
        _ecrire_montant(feuille, ligne, COLONNE_F, nettes_courtes)
        _ecrire_montant(feuille, ligne, COLONNE_G, assiette)
        exigence = assiette * _ponderation(feuille, ligne, colonne_ponderation)
        _ecrire_montant(feuille, ligne, COLONNE_EXIGENCE_EP26, exigence)
        return exigence

    # Risque spécifique : le portefeuille liquide et bien diversifié est
    # pondéré à 4 %, les autres actions à 8 %.
    specifique = ecrire_ligne("RM047", base_liquide, COLONNE_PONDERATION_EP26)
    specifique += ecrire_ligne("RM048", base_autre, COLONNE_PONDERATION_EP26)
    _ecrire_montant(
        feuille, lignes.get("RM049", 0), COLONNE_EXIGENCE_EP26, specifique
    )

    # Risque général : l'application ne suit pas de contrat à terme sur indice
    # (RM050, 2 %). L'assiette entière relève donc des autres actions.
    general = ecrire_ligne("RM050", 0.0, COLONNE_PONDERATION_EP26)
    general += ecrire_ligne("RM051", base_generale, COLONNE_PONDERATION_EP26)
    _ecrire_montant(feuille, lignes.get("RM052", 0), COLONNE_EXIGENCE_EP26, general)

    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_EXIGENCE_EP26 + 1))
    return []


def _remplir_ep27(classeur, positions: dict[str, Any] | None) -> list[Reserve]:
    """Détaille le risque de change.

    L'exigence porte sur la position nette globale, c'est-à-dire le plus élevé
    des deux sens — et non leur somme : un établissement long de 100 et court
    de 30 ne risque que sur 100.
    """

    feuille = classeur["EP27"]
    lignes = indexer_codes_dispru(feuille)
    change = (positions or {}).get("change")
    if not isinstance(change, dict):
        return []

    longues = flottant(change.get("longues"))
    courtes = flottant(change.get("courtes"))
    nette_globale = flottant(change.get("position_nette_globale"))

    ligne = lignes.get("RM060", 0)
    if ligne:
        _ecrire_montant(feuille, ligne, COLONNE_C, longues)
        _ecrire_montant(feuille, ligne, COLONNE_D, courtes)
        _ecrire_montant(feuille, ligne, COLONNE_E, longues)
        _ecrire_montant(feuille, ligne, COLONNE_F, courtes)
        # Seul le sens retenu porte l'exigence : l'autre est déclaré à zéro.
        _ecrire_montant(
            feuille, ligne, COLONNE_G, nette_globale if longues >= courtes else 0.0
        )
        _ecrire_montant(
            feuille, ligne, COLONNE_H, 0.0 if longues >= courtes else nette_globale
        )
        exigence = nette_globale * _ponderation(
            feuille, ligne, COLONNE_PONDERATION_EP27
        )
        _ecrire_montant(feuille, ligne, COLONNE_EXIGENCE_EP27, exigence)
        _ecrire_montant(
            feuille, lignes.get("RM062", 0), COLONNE_EXIGENCE_EP27, exigence
        )

    # RM061 (or) et le bloc des options restent à zéro : l'application ne suit
    # ni position sur or ni option de change.
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_EXIGENCE_EP27 + 1))
    return [
        information(
            "EP27 : les positions sur or (RM061) et les exigences sur options "
            "(RM063 à RM065) sont déclarées à zéro, l'application ne les "
            "suivant pas."
        )
    ]


# ─── EP30 : détail des clients au sein des groupes ────────────────────────


def _lire_membres_de_groupes() -> list[dict[str, Any]]:
    """Contreparties rattachées à un groupe de clients liés.

    Une contrepartie sans groupe n'a pas sa place dans l'EP30 : l'état ne
    décrit que les clients appartenant à un groupe, pas le portefeuille.
    """

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT g.numero_centrale_risques AS numero_groupe,
                   g.nom                     AS nom_groupe,
                   c.numero_centrale_risques AS numero_contrepartie,
                   c.categorie_lien          AS categorie_lien,
                   c.nom                     AS nom,
                   c.pays                    AS pays,
                   c.secteur_activite        AS secteur
            FROM contreparties c
            JOIN groupes_clients g ON g.id = c.groupe_id
            ORDER BY g.nom, c.nom
            """
        ).fetchall()
    return [dict(ligne) for ligne in lignes]


def _remplir_ep30(classeur, groupes: dict[str, dict[str, Any]]) -> list[Reserve]:
    """Détaille chaque client des groupes de clients liés.

    Les montants proviennent de l'agrégation déjà servie aux états EP29, EP31
    et EP32 : les quatre états doivent raconter la même histoire.
    """

    feuille = classeur["EP30"]
    lignes = indexer_codes_dispru(feuille)
    codes = sorted(code for code in lignes if code.startswith("GR"))
    membres = _lire_membres_de_groupes()

    if not membres:
        return [
            a_verifier(
                "EP30 : aucune contrepartie n'est rattachée à un groupe de "
                "clients liés. L'état reste vide, et la division des risques "
                "(EP29, EP31, EP32) traite chaque contrepartie comme un groupe "
                "à elle seule — ce qui sous-estime les concentrations."
            )
        ]

    anomalies: list[Reserve] = []
    if len(membres) > len(codes):
        anomalies.append(a_verifier(
            f"EP30 : {len(membres)} clients de groupes pour {len(codes)} lignes "
            "disponibles. Les derniers ont été écartés."
        ))
        membres = membres[: len(codes)]

    incomplets = 0
    for code, membre in zip(codes, membres):
        ligne = lignes[code]
        agrege = groupes.get(str(membre["nom"]), {})
        exposition = _exposition_totale(agrege) if agrege else 0.0

        _ecrire(feuille, ligne, COLONNE_B, membre["numero_groupe"] or "")
        _ecrire(feuille, ligne, COLONNE_C, membre["numero_contrepartie"] or "")
        # Le formulaire attend la nature du lien en clair, pas l'identifiant
        # technique : c'est elle qui justifie l'addition des risques.
        _ecrire(
            feuille,
            ligne,
            COLONNE_D,
            LIBELLES_LIENS.get(str(membre["categorie_lien"] or ""), ""),
        )
        _ecrire(feuille, ligne, COLONNE_E, membre["nom"])
        _ecrire(feuille, ligne, COLONNE_F, membre["pays"] or "")
        _ecrire(feuille, ligne, COLONNE_G, membre["secteur"] or "")
        _ecrire_montant(feuille, ligne, COLONNE_H, exposition)
        _ecrire_montant(feuille, ligne, COLONNE_I, flottant(agrege.get("souffrance")))
        # Le formulaire ventile ensuite l'exposition brute de bilan entre
        # prêts, titres de créances et participations. L'application ne
        # distingue pas ces natures : la totalité est portée en prêts, la
        # ventilation la plus proche de la réalité d'un portefeuille de crédit.
        _ecrire_montant(feuille, ligne, COLONNE_J, flottant(agrege.get("bilan")))
        # Le hors-bilan se ventile de même entre engagements de financement,
        # dérivés et autres engagements. Faute de cette distinction, tout est
        # porté en engagements de financement — l'omettre ferait apparaître la
        # contrepartie sans hors-bilan, en contradiction avec les états EP29,
        # EP31 et EP32 qui décrivent la même population.
        _ecrire_montant(feuille, ligne, COLONNE_M, flottant(agrege.get("hors_bilan")))

        if not (membre["numero_groupe"] and membre["numero_contrepartie"]):
            incomplets += 1

    if incomplets:
        anomalies.append(a_verifier(
            f"EP30 : {incomplets} client(s) sans numéro Centrale des risques. "
            "Ces colonnes d'identification sont exigées par le formulaire."
        ))
    anomalies.append(convention(
        "EP30 : l'exposition de bilan est portée en totalité sur « Prêts, "
        "avances et crédits-bails ». L'application ne distingue pas les titres "
        "de créances des participations au sein d'une exposition."
    ))
    completer_a_zero(feuille, lignes, range(COLONNE_H, COLONNE_M + 3))
    return anomalies


# ─── EP34 et EP35 : participations ────────────────────────────────────────

# Les cinq sections de l'EP34, chacune close par sa ligne de total. Les vingt
# lignes de saisie d'une section sont déduites de ses bornes plutôt que
# codées : le formulaire les numérote continûment.
SECTIONS_EP34: tuple[tuple[str, int, int, str], ...] = (
    ("etablissement", 1, 20, "PA021"),
    ("assurance", 22, 41, "PA042"),
    ("autre_financiere", 43, 62, "PA063"),
    ("societe_immobiliere", 64, 83, "PA084"),
    ("entite_commerciale", 85, 104, "PA105"),
)
CODE_TOTAL_EP34 = "PA106"

# Bloc principal de l'EP35 : les seules entités commerciales y figurent.
PREMIER_CODE_EP35, DERNIER_CODE_EP35 = 107, 127


def _codes_participations(premier: int, dernier: int) -> tuple[str, ...]:
    return tuple(f"PA{numero:03d}" for numero in range(premier, dernier + 1))


def _remplir_ep34(classeur, participations: list[Any]) -> list[Reserve]:
    """Liste les participations par section, avec le total de chacune."""

    feuille = classeur["EP34"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []
    total_general = 0.0

    for categorie, premier, dernier, code_total in SECTIONS_EP34:
        retenues = [p for p in participations if p.categorie == categorie]
        codes = _codes_participations(premier, dernier)
        if len(retenues) > len(codes):
            anomalies.append(a_verifier(
                f"EP34 : {len(retenues)} participations relèvent de la section "
                f"« {categorie} » alors que le formulaire n'offre que "
                f"{len(codes)} lignes. Les plus faibles ont été écartées."
            ))
            retenues = sorted(retenues, key=lambda p: p.montant_net, reverse=True)
            retenues = retenues[: len(codes)]

        total_section = 0.0
        for code, participation in zip(codes, retenues):
            ligne = lignes.get(code, 0)
            _ecrire(feuille, ligne, COLONNE_B, participation.denomination)
            _ecrire_montant(feuille, ligne, COLONNE_C, participation.capital_entreprise)
            _ecrire_montant(feuille, ligne, COLONNE_D, participation.montant_brut)
            _ecrire_montant(feuille, ligne, COLONNE_E, participation.montant_net)
            total_section += participation.montant_net

        ligne_total = lignes.get(code_total, 0)
        _ecrire_montant(feuille, ligne_total, COLONNE_D, sum(p.montant_brut for p in retenues))
        _ecrire_montant(feuille, ligne_total, COLONNE_E, total_section)
        total_general += total_section

    ligne_generale = lignes.get(CODE_TOTAL_EP34, 0)
    _ecrire_montant(
        feuille, ligne_generale, COLONNE_D, sum(p.montant_brut for p in participations)
    )
    _ecrire_montant(feuille, ligne_generale, COLONNE_E, total_general)
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_E + 1))
    return anomalies


def _remplir_ep35(
    classeur,
    participations: list[Any],
    fonds_propres_t1: float,
    fonds_propres_effectifs: float,
) -> list[Reserve]:
    """Détaille les participations dans les entités commerciales et leurs ratios."""

    feuille = classeur["EP35"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    commerciales = sorted(
        (p for p in participations if p.categorie == "entite_commerciale"),
        key=lambda p: p.montant_net,
        reverse=True,
    )
    codes = _codes_participations(PREMIER_CODE_EP35, DERNIER_CODE_EP35)
    if len(commerciales) > len(codes):
        anomalies.append(a_verifier(
            f"EP35 : {len(commerciales)} participations dans des entités "
            f"commerciales pour {len(codes)} lignes disponibles. Les plus "
            "faibles ont été écartées."
        ))
        commerciales = commerciales[: len(codes)]

    total_net = sum(p.montant_net for p in commerciales)
    sans_capital = 0

    for code, participation in zip(codes, commerciales):
        ligne = lignes.get(code, 0)
        _ecrire(feuille, ligne, COLONNE_B, participation.denomination)
        _ecrire_montant(feuille, ligne, COLONNE_D, participation.capital_entreprise)
        _ecrire_montant(feuille, ligne, COLONNE_E, participation.montant_brut)
        _ecrire_montant(feuille, ligne, COLONNE_F, participation.montant_net)

        # d = b / a : souscription rapportée au capital de l'émetteur.
        if participation.capital_entreprise > 0:
            part_capital = participation.montant_brut / participation.capital_entreprise
            _ecrire(feuille, ligne, COLONNE_G, round(part_capital, 4))
        else:
            sans_capital += 1
        # e = c / FPB : montant libéré rapporté aux fonds propres de base.
        if fonds_propres_t1 > 0:
            _ecrire(
                feuille,
                ligne,
                COLONNE_H,
                round(participation.montant_net / fonds_propres_t1, 4),
            )

    # f = total de c / FPE : porté par la première ligne, comme le formulaire
    # le présente (une seule limite globale pour l'ensemble du bloc).
    if commerciales and fonds_propres_effectifs > 0:
        _ecrire(
            feuille,
            lignes.get(codes[0], 0),
            COLONNE_I,
            round(total_net / fonds_propres_effectifs, 4),
        )

    if sans_capital:
        anomalies.append(a_verifier(
            f"EP35 : {sans_capital} participation(s) sans capital d'émetteur "
            "renseigné. Le pourcentage du capital détenu, plafonné à 25 %, "
            "reste vide pour ces lignes."
        ))
    completer_a_zero(feuille, lignes, range(COLONNE_D, COLONNE_I + 1))
    return anomalies


# ─── EP36 à EP39 : immobilisations et parties liées ───────────────────────

# Les deux natures sont définies dans app.core.natures_immobilisations : le
# suivi des participations les lit aussi, ses limites RA009 et RA010
# additionnant immobilisations et participations.

# Colonnes de l'EP38 et de l'EP39, dans l'ordre du formulaire. Les huit
# catégories de bénéficiaires sont celles que la base enregistre : aucune
# traduction n'est nécessaire, seulement un rang.
COLONNES_PARTIES_LIEES: tuple[tuple[str, int], ...] = (
    ("actionnaire", COLONNE_C),
    ("organe_deliberant", COLONNE_D),
    ("organe_executif", COLONNE_E),
    ("commissaire_comptes", COLONNE_F),
    ("personnel_direction", COLONNE_G),
    ("cadre", COLONNE_H),
    ("personnel_execution", COLONNE_I),
    ("autre_partie_liee", COLONNE_J),
)

# Colonnes de synthèse de l'EP38 : total des huit catégories, part des fonds
# propres effectifs, et dépassement du plafond de 20 %.
COLONNE_TOTAL_EP38 = COLONNE_K
COLONNE_RATIO_EP38 = COLONNE_L
COLONNE_EXCEDENT_EP38 = COLONNE_M
PLAFOND_PARTIES_LIEES = 0.20


@dataclass
class SyntheseImmobilisations:
    """Immobilisations déclarées, ventilées selon les besoins du formulaire."""

    exploitation_brut: float = 0.0
    exploitation_net: float = 0.0
    hors_exploitation_brut: float = 0.0
    hors_exploitation_net: float = 0.0

    @property
    def total_net(self) -> float:
        return self.exploitation_net + self.hors_exploitation_net


def _lire_immobilisations() -> SyntheseImmobilisations:
    """Montants d'immobilisations, par nature déclarée à l'import."""

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT a.type_actif AS nature,
                   SUM(e.montant_brut) AS brut,
                   SUM(e.ead)          AS net
            FROM exposition_autre_actif a
            JOIN expositions e ON e.id = a.exposition_id
            WHERE a.type_actif IN (?, ?)
            GROUP BY a.type_actif
            """,
            (NATURE_IMMO_EXPLOITATION, NATURE_IMMO_HORS_EXPLOITATION),
        ).fetchall()

    synthese = SyntheseImmobilisations()
    for ligne in lignes:
        if str(ligne["nature"]) == NATURE_IMMO_HORS_EXPLOITATION:
            synthese.hors_exploitation_brut = flottant(ligne["brut"])
            synthese.hors_exploitation_net = flottant(ligne["net"])
        else:
            synthese.exploitation_brut = flottant(ligne["brut"])
            synthese.exploitation_net = flottant(ligne["net"])
    return synthese


def _lire_immobilisations_incorporelles() -> float:
    """Immobilisations incorporelles nettes, pour le poste mémoire de l'EP3M.

    Elles sont lues à part des autres immobilisations : celles-ci alimentent
    l'EP36 et l'EP37, où elles sont pondérées, alors que les incorporelles se
    retranchent des fonds propres et n'entrent dans aucun actif pondéré.
    """

    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            """
            SELECT SUM(e.ead) AS net
            FROM exposition_autre_actif a
            JOIN expositions e ON e.id = a.exposition_id
            WHERE a.type_actif = ?
            """,
            (NATURE_IMMO_INCORPORELLE,),
        ).fetchone()
    return flottant(ligne["net"]) if ligne else 0.0


def _lire_parties_liees() -> list[dict[str, Any]]:
    """Contreparties rattachées à une catégorie de partie liée."""

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT nom, categorie_partie_liee AS categorie
            FROM contreparties
            WHERE categorie_partie_liee IS NOT NULL
            ORDER BY nom
            """
        ).fetchall()
    return [dict(ligne) for ligne in lignes]


def _remplir_ep36(
    classeur,
    immobilisations: SyntheseImmobilisations,
    participations_immobilieres: float,
    fonds_propres_t1: float,
) -> tuple[float, list[Reserve]]:
    """Immobilisations hors exploitation, plafonnées à 15 % des fonds propres."""

    feuille = classeur["EP36"]
    lignes = indexer_codes_dispru(feuille)

    _ecrire_montant(
        feuille, lignes.get("IM001", 0), COLONNE_C, immobilisations.hors_exploitation_brut
    )
    _ecrire_montant(
        feuille, lignes.get("IM001", 0), COLONNE_D, immobilisations.hors_exploitation_net
    )
    # IM002 et IM003 retranchent les immobilisations acquises par réalisation
    # de garantie, que l'application ne distingue pas : elles restent à zéro.
    _ecrire_montant(
        feuille, lignes.get("IM004", 0), COLONNE_C, immobilisations.hors_exploitation_brut
    )
    _ecrire_montant(
        feuille, lignes.get("IM004", 0), COLONNE_D, immobilisations.hors_exploitation_net
    )
    _ecrire_montant(feuille, lignes.get("PA084", 0), COLONNE_D, participations_immobilieres)

    total = immobilisations.hors_exploitation_net + participations_immobilieres
    _ecrire_montant(feuille, lignes.get("IM005", 0), COLONNE_D, total)
    ratio = total / fonds_propres_t1 if fonds_propres_t1 > 0 else 0.0
    _ecrire(feuille, lignes.get("IM005", 0), COLONNE_E, round(ratio, 4))
    # L'excédent est le dépassement du plafond de 15 % des fonds propres de base.
    excedent = max(0.0, total - 0.15 * fonds_propres_t1)
    _ecrire_montant(feuille, lignes.get("IM005", 0), COLONNE_F, excedent)
    _ecrire_montant(feuille, lignes.get("FPI29 / FPC29", 0), COLONNE_C, fonds_propres_t1)

    anomalies: list[Reserve] = []
    if not immobilisations.hors_exploitation_net:
        anomalies.append(a_verifier(
            "EP36 : aucune immobilisation n'est déclarée « hors exploitation ». "
            "Si l'établissement en détient, classez-la sous cette nature à "
            "l'import — sa limite prudentielle reste sinon non mesurée."
        ))
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_F + 1))
    return ratio, anomalies


def _remplir_ep37(
    classeur,
    immobilisations: SyntheseImmobilisations,
    total_participations: float,
    fonds_propres_effectifs: float,
) -> float:
    """Immobilisations et participations, plafonnées aux fonds propres effectifs."""

    feuille = classeur["EP37"]
    lignes = indexer_codes_dispru(feuille)

    _ecrire_montant(
        feuille, lignes.get("IM007", 0), COLONNE_C, immobilisations.exploitation_brut
    )
    _ecrire_montant(
        feuille, lignes.get("IM007", 0), COLONNE_D, immobilisations.exploitation_net
    )
    _ecrire_montant(
        feuille, lignes.get("IM004", 0), COLONNE_C, immobilisations.hors_exploitation_brut
    )
    _ecrire_montant(
        feuille, lignes.get("IM004", 0), COLONNE_D, immobilisations.hors_exploitation_net
    )
    _ecrire_montant(feuille, lignes.get("IM008", 0), COLONNE_D, immobilisations.total_net)
    _ecrire_montant(feuille, lignes.get("PA106", 0), COLONNE_D, total_participations)

    total = immobilisations.total_net + total_participations
    _ecrire_montant(feuille, lignes.get("IM009", 0), COLONNE_D, total)
    ratio = total / fonds_propres_effectifs if fonds_propres_effectifs > 0 else 0.0
    _ecrire(feuille, lignes.get("IM009", 0), COLONNE_E, round(ratio, 4))
    # Le plafond vaut ici 100 % des fonds propres effectifs.
    _ecrire_montant(
        feuille,
        lignes.get("IM009", 0),
        COLONNE_F,
        max(0.0, total - fonds_propres_effectifs),
    )
    _ecrire_montant(
        feuille, lignes.get("FPI41 / FPC41", 0), COLONNE_C, fonds_propres_effectifs
    )
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_F + 1))
    return ratio


def _remplir_ep38(
    classeur,
    groupes: dict[str, dict[str, Any]],
    parties_liees: list[dict[str, Any]],
    fonds_propres_effectifs: float,
) -> tuple[float, list[Reserve]]:
    """Concours aux actionnaires, dirigeants et personnel, par catégorie."""

    feuille = classeur["EP38"]
    lignes = indexer_codes_dispru(feuille)

    concours: dict[str, float] = {cle: 0.0 for cle, _ in COLONNES_PARTIES_LIEES}
    signature: dict[str, float] = {cle: 0.0 for cle, _ in COLONNES_PARTIES_LIEES}
    for partie in parties_liees:
        categorie = str(partie["categorie"])
        if categorie not in concours:
            continue
        agrege = groupes.get(str(partie["nom"]))
        if not agrege:
            continue
        concours[categorie] += flottant(agrege.get("bilan"))
        signature[categorie] += flottant(agrege.get("hors_bilan"))

    total_general = 0.0
    for categorie, colonne in COLONNES_PARTIES_LIEES:
        _ecrire_montant(feuille, lignes.get("PR001", 0), colonne, concours[categorie])
        _ecrire_montant(feuille, lignes.get("PR002", 0), colonne, signature[categorie])
        total = concours[categorie] + signature[categorie]
        _ecrire_montant(feuille, lignes.get("PR003", 0), colonne, total)
        total_general += total

    # Colonne TOTAL : la somme des huit catégories, ligne par ligne.
    for code, montants in (("PR001", concours), ("PR002", signature)):
        _ecrire_montant(
            feuille, lignes.get(code, 0), COLONNE_TOTAL_EP38, sum(montants.values())
        )
    _ecrire_montant(
        feuille, lignes.get("PR003", 0), COLONNE_TOTAL_EP38, total_general
    )

    # Le pourcentage et l'excédent sont fusionnés sur les trois lignes : ils
    # portent sur le total des engagements, et sont écrits une seule fois.
    ratio = total_general / fonds_propres_effectifs if fonds_propres_effectifs > 0 else 0.0
    _ecrire(feuille, lignes.get("PR003", 0), COLONNE_RATIO_EP38, round(ratio, 4))
    _ecrire_montant(
        feuille,
        lignes.get("PR003", 0),
        COLONNE_EXCEDENT_EP38,
        max(0.0, total_general - PLAFOND_PARTIES_LIEES * fonds_propres_effectifs),
    )
    _ecrire_montant(
        feuille, lignes.get("FPI41 / FPC41", 0), COLONNE_C, fonds_propres_effectifs
    )

    anomalies: list[Reserve] = []
    if not parties_liees:
        anomalies.append(a_verifier(
            "EP38 : aucune contrepartie n'est signalée comme actionnaire, "
            "dirigeant ou membre du personnel. La limite correspondante de "
            "l'EP01 reste donc non mesurée."
        ))
    completer_a_zero(feuille, lignes, range(COLONNE_C, COLONNE_H + 1))
    return ratio, anomalies


def _remplir_ep39(classeur, parties_liees: list[dict[str, Any]]) -> list[Reserve]:
    """Liste nominative des actionnaires, dirigeants et membres du personnel."""

    feuille = classeur["EP39"]
    lignes = indexer_codes_dispru(feuille)
    codes = sorted(code for code in lignes if code.startswith("PR"))
    colonnes = dict(COLONNES_PARTIES_LIEES)

    anomalies: list[Reserve] = []
    if len(parties_liees) > len(codes):
        anomalies.append(a_verifier(
            f"EP39 : {len(parties_liees)} parties liées pour {len(codes)} lignes "
            "disponibles. Les dernières ont été écartées."
        ))
        parties_liees = parties_liees[: len(codes)]

    for code, partie in zip(codes, parties_liees):
        ligne = lignes[code]
        _ecrire(feuille, ligne, COLONNE_B, partie["nom"])
        colonne = colonnes.get(str(partie["categorie"]))
        if colonne:
            # Le formulaire coche la colonne du bénéficiaire ; une croix vaut
            # mieux qu'un montant, l'EP38 portant déjà les encours.
            _ecrire(feuille, ligne, colonne, "X")
    return anomalies


# ─── EP01 : conformité aux normes prudentielles ───────────────────────────


def _remplir_ep01(
    classeur,
    fonds_propres: dict[str, float],
    apr_total: float,
    ratio_division: float,
    ratio_levier: float,
    synthese_participations: Any = None,
    ratios_encours: dict[str, float] | None = None,
) -> list[Reserve]:
    feuille = classeur["EP01"]
    lignes = indexer_codes_dispru(feuille)
    colonne = COLONNE_G

    def ratio(numerateur: float) -> float:
        return round(numerateur / apr_total, 4) if apr_total > 0 else 0.0

    _ecrire(feuille, lignes.get("RA001", 0), colonne, ratio(fonds_propres["cet1"]))
    _ecrire(feuille, lignes.get("RA002", 0), colonne, ratio(fonds_propres["t1"]))
    _ecrire(
        feuille, lignes.get("RA003", 0), colonne, ratio(fonds_propres["total_capital"])
    )
    _ecrire(feuille, lignes.get("RA004", 0), colonne, round(ratio_division, 4))
    _ecrire(feuille, lignes.get("RA005", 0), colonne, round(ratio_levier, 4))

    # Les trois limites sur les participations dans les entités commerciales.
    # Elles ne valent que si des participations sont suivies : à défaut, elles
    # restent nulles et rejoignent les normes signalées ci-dessous.
    if synthese_participations is not None:
        _ecrire(
            feuille,
            lignes.get("RA006", 0),
            colonne,
            round(synthese_participations.ratio_max_capital_emetteur, 4),
        )
        _ecrire(
            feuille,
            lignes.get("RA007", 0),
            colonne,
            round(synthese_participations.ratio_max_fonds_propres_t1, 4),
        )
        _ecrire(
            feuille,
            lignes.get("RA008", 0),
            colonne,
            round(synthese_participations.ratio_global_fonds_propres_effectifs, 4),
        )
    completer_a_zero(feuille, lignes, range(colonne, colonne + 1))

    # La colonne « Situation de l'établissement » est calculée par le
    # formulaire : un niveau observé nul y devient « CONFORME ». Pour les
    # normes que l'application ne mesure pas — participations, immobilisations
    # hors exploitation, prêts aux actionnaires et dirigeants — cette
    # conformité n'est pas constatée, elle est déduite d'une absence de
    # données. Le lecteur doit le savoir avant de signer l'attestation.
    # RA009 à RA011 : immobilisations hors exploitation, total des
    # immobilisations et participations, prêts aux parties liées.
    ratios_encours = ratios_encours or {}
    codes_encours = {"RA009": "immobilisations", "RA010": "immobilisations_participations",
                     "RA011": "parties_liees"}
    for code, cle in codes_encours.items():
        if cle in ratios_encours:
            _ecrire(feuille, lignes.get(code, 0), colonne, round(ratios_encours[cle], 4))

    codes_non_mesures = [
        code
        for code in NORMES_EP01_NON_MESUREES
        if not ratios_encours.get(codes_encours.get(code, ""), 0.0)
    ]
    if synthese_participations is None or not synthese_participations.total_general:
        # Aucune participation suivie : les trois limites sur les entités
        # commerciales retombent dans le même travers que les autres.
        codes_non_mesures = ["RA006", "RA007", "RA008", *codes_non_mesures]

    non_mesurees = [
        str(feuille.cell(row=lignes[code], column=COLONNE_B).value or code).strip()
        for code in codes_non_mesures
        if code in lignes
    ]
    if not non_mesurees:
        return []
    return [
        a_verifier(
            "EP01 : les normes suivantes sont déclarées à 0 %, donc "
            "« CONFORME », alors que l'application ne suit pas les encours "
            "correspondants (états EP34 à EP38) — "
            + " ; ".join(non_mesurees)
            + ". Vérifiez-les avant transmission."
        )
    ]


# ─── Attestation ──────────────────────────────────────────────────────────


# ─── EP3M : poste pour mémoire des déductions de fonds propres ─────────────

# Catégories de participations que la section C de l'EP3M recense. Elle ne vise
# que le secteur financier : les participations commerciales relèvent de l'EP35
# et de ses trois limites, les sociétés immobilières de l'EP36.
CATEGORIES_EP3M_ETABLISSEMENTS = frozenset({"etablissement"})
CATEGORIES_EP3M_AUTRES_FINANCIERES = frozenset({"assurance", "autre_financiere"})

# Au-delà de ce seuil de détention, une participation est « significative » et
# suit un régime de déduction distinct.
SEUIL_PARTICIPATION_SIGNIFICATIVE = 0.10


def _remplir_ep3m(
    classeur,
    participations: list[Any],
    immobilisations_incorporelles: float,
) -> list[Reserve]:
    """Poste pour mémoire des déductions applicables aux fonds propres.

    Deux sections sont alimentées. La section A porte les immobilisations
    incorporelles, qui se retranchent du CET1. La section C ventile les
    participations dans le secteur financier, d'abord par nature d'émetteur,
    puis selon qu'elles dépassent ou non le seuil de détention de 10 %.

    Le reste de l'état — impôts différés, ventilation par catégorie de fonds
    propres, seuils de 10 % et de 15 % — reste à zéro : l'application n'en
    tient pas encore la source, et le déclarer autrement serait inventer.
    """

    feuille = classeur["EP3M"]
    lignes = indexer_codes_dispru(feuille)
    anomalies: list[Reserve] = []

    _ecrire_montant(
        feuille, lignes.get("IM011", 0), COLONNE_C, immobilisations_incorporelles
    )

    financieres = [
        participation
        for participation in participations
        if participation.categorie
        in (CATEGORIES_EP3M_ETABLISSEMENTS | CATEGORIES_EP3M_AUTRES_FINANCIERES)
    ]

    total_etablissements = sum(
        participation.montant_net
        for participation in financieres
        if participation.categorie in CATEGORIES_EP3M_ETABLISSEMENTS
    )
    total_autres = sum(
        participation.montant_net
        for participation in financieres
        if participation.categorie in CATEGORIES_EP3M_AUTRES_FINANCIERES
    )

    # Le caractère significatif se lit sur la part du capital détenue, comme à
    # l'EP35 : souscription rapportée au capital de l'émetteur.
    significatives = 0.0
    non_significatives = 0.0
    sans_capital = 0
    for participation in financieres:
        if participation.capital_entreprise > 0:
            part = participation.montant_brut / participation.capital_entreprise
        else:
            # Sans capital de l'émetteur, la part ne se calcule pas. La
            # participation est rangée parmi les non significatives, qui est le
            # traitement le moins favorable pour l'établissement : une
            # déduction y est plafonnée, non écartée.
            part = 0.0
            sans_capital += 1
        if part > SEUIL_PARTICIPATION_SIGNIFICATIVE:
            significatives += participation.montant_net
        else:
            non_significatives += participation.montant_net

    _ecrire_montant(feuille, lignes.get("PA150", 0), COLONNE_C, total_etablissements)
    _ecrire_montant(feuille, lignes.get("PA151", 0), COLONNE_C, total_autres)
    _ecrire_montant(
        feuille, lignes.get("PA152", 0), COLONNE_C, total_etablissements + total_autres
    )
    _ecrire_montant(feuille, lignes.get("PA154", 0), COLONNE_C, non_significatives)
    _ecrire_montant(feuille, lignes.get("PA155", 0), COLONNE_C, significatives)

    if sans_capital:
        anomalies.append(a_verifier(
            f"EP3M : {sans_capital} participation(s) financière(s) sans capital "
            "de l'émetteur. Leur part de détention étant inconnue, elles sont "
            "rangées parmi les participations non significatives. Renseignez "
            "le capital pour que le seuil de 10 % les classe réellement."
        ))
    if financieres and not immobilisations_incorporelles:
        anomalies.append(a_verifier(
            "EP3M : aucune immobilisation incorporelle n'est déclarée. Si "
            "l'établissement en détient, classez-la sous cette nature à "
            "l'import — elle se déduit des fonds propres de base."
        ))
    return anomalies


def _remplir_attestation(classeur, date_arrete: date) -> None:
    """Inscrit la date d'arrêté dans le gabarit AAAA / MM / JJ de l'attestation."""

    feuille = classeur["ADPE"]
    gabarit = (
        ("D7", "E7", "F7", "G7", f"{date_arrete.year:04d}"),
        ("H7", "I7", None, None, f"{date_arrete.month:02d}"),
        ("K7", "L7", None, None, f"{date_arrete.day:02d}"),
    )
    for groupe in gabarit:
        cellules = [reference for reference in groupe[:-1] if reference]
        chiffres = groupe[-1]
        for reference, chiffre in zip(cellules, chiffres):
            feuille[reference] = chiffre


# ─── Point d'entrée ───────────────────────────────────────────────────────


def construire_fodep(date_arrete: date | None = None) -> ResultatFodep:
    """Produit le classeur FODEP renseigné, prêt à être transmis.

    C'est la forme déclarative : un fichier. L'aperçu, lui, passe par
    `renseigner_classeur_fodep` et lit le classeur sans l'écrire.
    """

    produit = renseigner_classeur_fodep(date_arrete)
    try:
        tampon = BytesIO()
        produit.classeur.save(tampon)
        return ResultatFodep(
            contenu=tampon.getvalue(),
            date_arrete=produit.date_arrete,
            anomalies=produit.anomalies,
        )
    finally:
        produit.classeur.close()


def renseigner_classeur_fodep(date_arrete: date | None = None) -> ClasseurFodep:
    """Renseigne le classeur FODEP à partir des données du portefeuille.

    Le classeur est rendu ouvert : c'est à l'appelant de le refermer. Deux
    lectures en ont besoin — l'export, qui l'enregistre, et l'aperçu, qui le
    parcourt — et rien ne justifie de l'écrire sur disque pour le relire aussitôt.
    """

    if not CHEMIN_MODELE.exists():
        raise FileNotFoundError(
            "Le modèle FODEP est absent de l'installation "
            f"({CHEMIN_MODELE}). Régénérez-le avec "
            "scripts/preparer_modele_fodep.py."
        )

    expositions = exposure_repository.list_exposures()
    date_effective = date_arrete or _date_arrete_par_defaut(expositions)

    classeur = load_workbook(CHEMIN_MODELE)
    try:
        paliers = _paliers_par_categorie(classeur)
        synthese = agreger_risque_credit(expositions, paliers)
        aligner_sur_les_paliers(synthese, paliers)

        fonds_propres_saisis = _lire_fonds_propres()
        fonds_propres, anomalies_fp = _remplir_ep03(classeur, fonds_propres_saisis)
        anomalies = list(synthese.anomalies) + anomalies_fp

        _remplir_ep09(classeur, synthese)
        _remplir_ep10(classeur, synthese)
        apr_par_categorie = _remplir_etats_categories(classeur, synthese)
        apr_autres_actifs = _remplir_ep20(classeur, synthese)
        # Un établissement applique une méthode de risque opérationnel, pas
        # les deux : l'approche standard demande l'accord de la Commission
        # bancaire, et c'est cet accord — enregistré sur l'écran du FODEP —
        # qui décide de l'état renseigné. L'autre reste à zéro.
        approche_standard = get_as_parametres().as_autorisee
        if approche_standard:
            apr_operationnel, anomalies_ro = _remplir_ep23(classeur)
            anomalies.extend(anomalies_ro)
            anomalies.extend(_remplir_ep24(classeur, date_effective))
        else:
            apr_operationnel, anomalies_ro = _remplir_ep21(classeur)
            anomalies.extend(anomalies_ro)
            anomalies.extend(_remplir_ep22(classeur, date_effective))

        participations = lister_participations()
        synthese_participations = calculer_synthese(
            participations,
            fonds_propres_t1=fonds_propres["t1"],
            fonds_propres_effectifs=fonds_propres["total_capital"],
        )
        # L'EP3M vient avant le balayage à zéro des états non alimentés : ce
        # dernier ne remplit que les cases restées vides.
        anomalies.extend(
            _remplir_ep3m(
                classeur,
                participations,
                _lire_immobilisations_incorporelles(),
            )
        )
        anomalies.extend(_remplir_ep34(classeur, participations))
        anomalies.extend(
            _remplir_ep35(
                classeur,
                participations,
                fonds_propres["t1"],
                fonds_propres["total_capital"],
            )
        )

        risque_marche = _lire_risque_marche()
        apr_marche = flottant(risque_marche.get("rwa_marche"))
        ventilation_marche = risque_marche.get("ventilation") or None
        if apr_marche and not ventilation_marche:
            anomalies.append(a_verifier(
                "Risque de marché : aucun détail par nature n'a été transmis "
                "par le module. Les lignes de détail de l'EP08 (taux, titres "
                "de propriété, change, produits de base) restent à zéro, seul "
                "leur total est déclaré. Rouvrez l'écran Risque de Marché pour "
                "que le détail soit enregistré."
            ))
        elif apr_marche:
            positions_marche = risque_marche.get("positions")
            if positions_marche:
                anomalies.extend(_remplir_ep25(classeur, positions_marche))
                anomalies.extend(_remplir_ep26(classeur, positions_marche))
                anomalies.extend(_remplir_ep27(classeur, positions_marche))
                anomalies.append(information(
                    "Risque de marché : l'EP28 (produits de base), les "
                    "positions sur or et les exigences sur options sont "
                    "déclarées à zéro. L'établissement n'en détient aucune."
                ))
            else:
                anomalies.append(a_verifier(
                    "Risque de marché : les lignes de détail de l'EP08 sont "
                    "renseignées, mais les positions longues et courtes n'ont "
                    "pas été transmises : les états EP25 à EP28 restent à zéro. "
                    "Rouvrez l'écran Risque de Marché pour les enregistrer."
                ))

        apr_total = _remplir_ep08(
            classeur,
            apr_par_categorie,
            apr_autres_actifs,
            apr_marche,
            apr_operationnel,
            ventilation_marche,
            approche_standard=approche_standard,
        )
        _remplir_ep02(classeur, fonds_propres, apr_total)
        groupes = _agreger_par_contrepartie(expositions)
        ratio_division = _remplir_ep29(classeur, groupes, fonds_propres["t1"])
        anomalies.extend(_remplir_ep30(classeur, groupes))
        _remplir_ep31(classeur, groupes)
        _remplir_ep32(classeur, groupes)

        # Immobilisations et parties liées : les trois dernières normes de
        # l'EP01 en dépendent.
        immobilisations = _lire_immobilisations()
        parties_liees = _lire_parties_liees()
        ratio_immo, anomalies_ep36 = _remplir_ep36(
            classeur,
            immobilisations,
            synthese_participations.totaux_par_categorie.get("societe_immobiliere", 0.0),
            fonds_propres["t1"],
        )
        anomalies.extend(anomalies_ep36)
        ratio_immo_participations = _remplir_ep37(
            classeur,
            immobilisations,
            synthese_participations.total_general,
            fonds_propres["total_capital"],
        )
        ratio_parties_liees, anomalies_ep38 = _remplir_ep38(
            classeur, groupes, parties_liees, fonds_propres["total_capital"]
        )
        anomalies.extend(anomalies_ep38)
        anomalies.extend(_remplir_ep39(classeur, parties_liees))
        ratio_levier = _remplir_ep33(classeur, synthese, fonds_propres["t1"])
        anomalies.extend(
            _remplir_ep01(
                classeur,
                fonds_propres,
                apr_total,
                ratio_division,
                ratio_levier,
                synthese_participations,
                {
                    "immobilisations": ratio_immo,
                    "immobilisations_participations": ratio_immo_participations,
                    "parties_liees": ratio_parties_liees,
                },
            )
        )
        _remplir_attestation(classeur, date_effective)
        # Les saisies manuelles passent avant tout balayage : les fonctions
        # qui suivent ne remplissent que les cases restées vides, une case
        # saisie n'est donc jamais recouverte par un zéro automatique.
        saisies_ecrites = appliquer_saisies(classeur)
        anomalies.extend(_declarer_etats_non_alimentes(classeur))
        _completer_les_etats_alimentes(classeur)
        if saisies_ecrites:
            anomalies.append(information(
                f"{saisies_ecrites} cellule(s) proviennent de la saisie "
                "manuelle des états non alimentés, et non d'un calcul de "
                "l'application. Elles engagent celui qui les a portées."
            ))

        _verifier_coherence_fonds_propres(fonds_propres, fonds_propres_saisis, anomalies)

        return ClasseurFodep(
            classeur=classeur,
            date_arrete=date_effective,
            # Une même réserve peut être soulevée par plusieurs expositions :
            # la répéter n'apprendrait rien de plus au lecteur.
            anomalies=list(dict.fromkeys(anomalies)),
        )
    except BaseException:
        # Le classeur n'est referme ici que si la production echoue : rendu a
        # l'appelant, il lui appartient, et le fermer serait le lui retirer.
        classeur.close()
        raise


def _completer_les_etats_alimentes(classeur) -> None:
    """Met à zéro les cases de saisie qu'aucun montant n'est venu remplir.

    Les fonctions de remplissage renseignent les lignes et les colonnes
    qu'elles connaissent : une colonne annexe, un bloc secondaire ou une ligne
    hors barème restent vides. Or la notice n'admet pas de case à renseigner
    laissée vide (§ 3.3), et un formulaire incomplet est rejeté.

    Ce balayage final ne touche jamais une case déjà écrite, ni les deux
    premières colonnes qui portent les codes DISPRU et les intitulés.
    """

    for etat in sorted(ETATS_ALIMENTES):
        if etat in classeur.sheetnames:
            completer_etat_a_zero(
                classeur[etat],
                premiere_colonne=PREMIERE_COLONNE_NUMERIQUE.get(etat, COLONNE_C),
            )


def _declarer_etats_non_alimentes(classeur) -> list[Reserve]:
    """Traite les états requis que les données de l'application ne couvrent pas.

    Le périmètre vient du formulaire : la feuille « Liste des états prudentiels
    à renseigner » indique, pour chaque base de déclaration, les états exigés.
    Ceux qui sont entièrement numériques sont déclarés à zéro ; les autres
    portent des colonnes d'identification qu'aucun zéro ne peut remplacer
    (nom de contrepartie, numéro Centrale des risques) et sont laissés à
    compléter, ce que l'export signale plutôt que de le passer sous silence.
    """

    requis = lire_etats_requis(classeur, base=BASE_DE_DECLARATION)
    anomalies: list[Reserve] = []

    for etat in sorted(requis & ETATS_DECLARES_A_ZERO):
        completer_etat_a_zero(classeur[etat])

    a_completer = sorted(requis - ETATS_ALIMENTES - ETATS_DECLARES_A_ZERO)
    if a_completer:
        anomalies.append(a_verifier(
            "États exigés sur base "
            f"{BASE_DE_DECLARATION} mais laissés vides, faute de source dans "
            f"l'application : {', '.join(a_completer)}. Ils portent des "
            "colonnes d'identification à saisir à la main."
        ))
    return anomalies


def _date_arrete_par_defaut(expositions: list[dict[str, Any]]) -> date:
    """Retient la date d'analyse la plus récente du portefeuille."""

    dates: list[date] = []
    for exposition in expositions:
        valeur = exposition.get("analysis_date")
        if isinstance(valeur, date):
            dates.append(valeur)
        elif valeur:
            try:
                dates.append(date.fromisoformat(str(valeur)[:10]))
            except ValueError:
                continue
    return max(dates) if dates else date.today()


def _verifier_coherence_fonds_propres(
    fonds_propres: dict[str, float],
    donnees_saisies: dict[str, float],
    anomalies: list[Reserve],
) -> None:
    """Signale tout écart entre l'EP03 et le calcul du tableau de bord."""

    reference = calculate_fonds_propres(donnees_saisies)
    for cle in ("cet1", "t1", "total_capital"):
        if abs(fonds_propres[cle] - reference[cle]) > 1.0:
            anomalies.append(a_verifier(
                f"Fonds propres « {cle} » : l'EP03 déclare "
                f"{fonds_propres[cle] / 1e6:,.0f} M FCFA, le tableau de bord "
                f"{reference[cle] / 1e6:,.0f} M FCFA."
            ))
