# -*- coding: utf-8 -*-
"""Génère les quatre modèles d'import Excel de l'outil RWA.

    python modeles_import/generer_modeles.py

Sortie (dans ce même dossier) :
    1_modele_import_risque_marche.xlsx
    2_modele_import_risque_operationnel.xlsx
    3_modele_import_risque_credit.xlsx
    4_modele_import_fonds_propres.xlsx

Le quatrième fichier est calibré sur les RWA effectivement produits par les
trois premiers : le RWA de crédit est obtenu en faisant tourner le moteur de
calcul prudentiel du backend sur les 1 000 expositions générées, le RWA de
marché par le portage Python des règles de l'écran Risque de marché, et le
RWA opérationnel par la formule BIC / CCR3 du backend.
"""

from __future__ import annotations

import sys
from pathlib import Path

DOSSIER = Path(__file__).resolve().parent
RACINE = DOSSIER.parent
sys.path.insert(0, str(DOSSIER))
sys.path.insert(0, str(RACINE / "backend"))

import calc_marche  # noqa: E402
import gen_credit  # noqa: E402
import gen_fp  # noqa: E402
import gen_marche  # noqa: E402
import gen_op  # noqa: E402

FICHIERS = {
    "marche": DOSSIER / "1_modele_import_risque_marche.xlsx",
    "operationnel": DOSSIER / "2_modele_import_risque_operationnel.xlsx",
    "credit": DOSSIER / "3_modele_import_risque_credit.xlsx",
    "fonds_propres": DOSSIER / "4_modele_import_fonds_propres.xlsx",
}

# Poids visés de chaque risque dans le RWA total. Le risque opérationnel sert
# d'ancrage : son RWA découle de l'indicateur d'activité, qu'on ne peut pas
# gonfler sans rendre le compte de résultat invraisemblable. Les portefeuilles
# de crédit et de marché sont ensuite dimensionnés pour atteindre ces parts.
POIDS_CIBLES = {"credit": 0.65, "marche": 0.25, "operationnel": 0.10}

TOLERANCE = 0.002
ITERATIONS_MAX = 6


def _md(montant: float) -> str:
    return f"{montant / 1e9:>12,.2f} Md".replace(",", " ")


def calculer_rwa_credit(template, crm_non_fin, crm_fin):
    """Rejoue le moteur de calcul prudentiel du backend sur les expositions
    générées, exactement comme le fait l'import Excel.

    Les agrégats sont exprimés en FCFA : le moteur conserve chaque montant
    dans la devise de l'exposition, et c'est le tableau de bord qui convertit
    au moment d'agréger (voir `_normalize_row` dans app/dashboard/services.py).
    Sommer les valeurs brutes reviendrait à additionner des devises.
    """
    from app.core.calculations import convert_currency_amount
    from app.core.excel_repository import excel_repository

    index_non_fin = excel_repository._crm_non_fin_by_rows(crm_non_fin)
    index_fin = excel_repository._crm_fin_by_rows(crm_fin)

    def en_xof(montant, devise) -> float:
        return convert_currency_amount(
            float(montant or 0.0), from_currency=devise, to_currency="XOF"
        )

    rwa_total = 0.0
    capital_total = 0.0
    ead_total = 0.0
    brut_total = 0.0
    par_categorie: dict[str, dict[str, float]] = {}
    echecs = []

    for ligne in template:
        identifiant = ligne["ID_Exposition"]
        try:
            enregistrement = excel_repository._build_exposure_from_template(
                ligne,
                crm_non_fin_row=index_non_fin.get(identifiant),
                crm_fin_row=index_fin.get(identifiant),
            )
        except Exception as erreur:  # pragma: no cover - diagnostic
            echecs.append((identifiant, str(erreur)))
            continue

        devise = enregistrement.get("currency") or "XOF"
        rwa = en_xof(enregistrement.get("rwa"), devise)
        brut = en_xof(enregistrement.get("gross_amount"), devise)
        rwa_total += rwa
        capital_total += en_xof(enregistrement.get("capital"), devise)
        ead_total += en_xof(enregistrement.get("ead"), devise)
        brut_total += brut

        categorie = ligne["Catégorie d'exposition"]
        agregat = par_categorie.setdefault(
            categorie, {"lignes": 0, "brut": 0.0, "rwa": 0.0}
        )
        agregat["lignes"] += 1
        agregat["brut"] += brut
        agregat["rwa"] += rwa

    return {
        "rwa": rwa_total,
        "capital": capital_total,
        "ead": ead_total,
        "brut": brut_total,
        "par_categorie": par_categorie,
        "echecs": echecs,
    }


def _resoudre_echelle(mesurer, cible: float, libelle: str) -> tuple[float, object]:
    """Cherche le facteur d'échelle donnant `cible` en RWA.

    Le RWA étant proportionnel aux encours à composition constante, une simple
    règle de trois converge en deux ou trois passes ; les quelques itérations
    supplémentaires absorbent les arrondis de montants.
    """
    echelle = 1.0
    resultat = None
    for passe in range(1, ITERATIONS_MAX + 1):
        resultat, rwa = mesurer(echelle)
        ecart = abs(rwa - cible) / cible
        print(
            f"      calage {libelle} : passe {passe} | echelle {echelle:6.4f} "
            f"| RWA {rwa / 1e9:8.2f} Md | ecart {ecart * 100:5.2f} %"
        )
        if ecart <= TOLERANCE:
            break
        echelle *= cible / rwa
    return echelle, resultat


def main() -> int:
    print("=" * 78)
    print("Generation des modeles d'import - Outil RWA")
    print("=" * 78)

    # ── Ancrage : le risque operationnel ───────────────────────────────────
    incidents = gen_op.construire_incidents()
    bic = gen_op.calculer_bic()
    rwa_operationnel = bic["rea_crr3"]
    rwa_total_cible = rwa_operationnel / POIDS_CIBLES["operationnel"]
    cible_credit = rwa_total_cible * POIDS_CIBLES["credit"]
    cible_marche = rwa_total_cible * POIDS_CIBLES["marche"]

    print("\n[0/4] Calibrage")
    print(f"      RWA operationnel (ancre) : {_md(rwa_operationnel)} FCFA")
    print(f"      RWA total vise           : {_md(rwa_total_cible)} FCFA")
    print(f"      cible credit (65 %)      : {_md(cible_credit)} FCFA")
    print(f"      cible marche (25 %)      : {_md(cible_marche)} FCFA")
    print()

    # ── 1. Risque de marché ────────────────────────────────────────────────
    def _mesurer_marche(echelle):
        obligations = gen_marche.construire_obligations(echelle=echelle)
        actions = gen_marche.construire_actions(echelle=echelle)
        resultat = calc_marche.exigence_totale(obligations, actions)
        return (obligations, actions, resultat), resultat["rwa_marche"]

    _echelle_marche, (obligations, actions, marche) = _resoudre_echelle(
        _mesurer_marche, cible_marche, "marche"
    )
    chemin_marche, valeur_obligations, valeur_actions = gen_marche.construire_classeur(
        FICHIERS["marche"], obligations, actions
    )
    print(f"\n[1/4] Risque de marche  -> {chemin_marche.name}")
    print(f"      obligations            : {len(obligations):>5} lignes")
    print(f"      actions                : {len(actions):>5} lignes")
    print(f"      encours obligataire    : {_md(valeur_obligations)} FCFA")
    print(f"      valorisation actions   : {_md(valeur_actions)} FCFA")
    print(f"      exigence taux          : {_md(marche['taux']['specifique'] + marche['taux']['general'])} FCFA")
    print(f"      exigence actions       : {_md(marche['actions']['specifique'] + marche['actions']['general'])} FCFA")
    print(f"      exigence change        : {_md(marche['change']['exigence'])} FCFA")
    print(f"      capital requis marche  : {_md(marche['capital_requis'])} FCFA")
    print(f"      RWA marche (x12,5)     : {_md(marche['rwa_marche'])} FCFA")

    # ── 2. Risque opérationnel ─────────────────────────────────────────────
    chemin_op, bic = gen_op.construire_classeur(FICHIERS["operationnel"], incidents)
    print(f"\n[2/4] Risque operationnel -> {chemin_op.name}")
    print(f"      incidents              : {len(incidents):>5} lignes")
    print(f"      perte brute cumulee    : {_md(sum(i['perte_brute'] for i in incidents))} FCFA")
    print(f"      BI (moyenne 3 ans)     : {_md(bic['bi'])} FCFA  (tranche {bic['tranche']})")
    print(f"      BIC = OFR CRR3         : {_md(bic['ofr_crr3'])} FCFA")
    print(f"      REA CRR3 (x12,5)       : {_md(bic['rea_crr3'])} FCFA")

    # ── 3. Risque de crédit ────────────────────────────────────────────────
    def _mesurer_credit(echelle):
        template, crm_non_fin, crm_fin = gen_credit.construire_donnees(echelle=echelle)
        credit = calculer_rwa_credit(template, crm_non_fin, crm_fin)
        return (template, crm_non_fin, crm_fin, credit), credit["rwa"]

    print()
    _echelle_credit, (template, crm_non_fin, crm_fin, credit) = _resoudre_echelle(
        _mesurer_credit, cible_credit, "credit"
    )
    chemin_credit = gen_credit.construire_classeur(
        FICHIERS["credit"], template, crm_non_fin, crm_fin
    )
    print(f"\n[3/4] Risque de credit  -> {Path(chemin_credit).name}")
    print(f"      expositions            : {len(template):>5} lignes")
    print(f"      CRM non financee       : {len(crm_non_fin):>5} lignes")
    print(f"      CRM financee           : {len(crm_fin):>5} lignes")
    print(f"      encours brut           : {_md(credit['brut'])} FCFA")
    print(f"      EAD totale             : {_md(credit['ead'])} FCFA")
    print(f"      RWA credit             : {_md(credit['rwa'])} FCFA")
    print(f"      capital requis credit  : {_md(credit['capital'])} FCFA")
    if credit["echecs"]:
        print(f"      !! {len(credit['echecs'])} ligne(s) en echec de calcul")
        for identifiant, message in credit["echecs"][:5]:
            print(f"         - {identifiant}: {message}")

    print("\n      Ventilation par categorie prudentielle :")
    print(f"      {'categorie':<32}{'lignes':>8}{'brut (Md)':>14}{'RWA (Md)':>12}{'densite':>10}")
    for categorie, agregat in sorted(
        credit["par_categorie"].items(), key=lambda item: -item[1]["rwa"]
    ):
        densite = agregat["rwa"] / agregat["brut"] if agregat["brut"] else 0.0
        print(
            f"      {categorie[:31]:<32}{agregat['lignes']:>8}"
            f"{agregat['brut'] / 1e9:>14,.1f}{agregat['rwa'] / 1e9:>12,.1f}"
            f"{densite * 100:>9.0f}%".replace(",", " ")
        )

    # ── 4. Fonds propres ───────────────────────────────────────────────────
    # Convention de l'outil : le tableau de bord additionne le RWA de crédit,
    # le RWA de marché et le REA CRR3 du risque opérationnel.
    rwa_total = credit["rwa"] + marche["rwa_marche"] + rwa_operationnel
    synthese = {
        "rwa_credit": credit["rwa"],
        "rwa_marche": marche["rwa_marche"],
        "rwa_operationnel": rwa_operationnel,
        "rwa_total": rwa_total,
    }
    calibration = gen_fp.calibrer(rwa_total)
    chemin_fp = gen_fp.construire_classeur(
        FICHIERS["fonds_propres"], calibration, synthese
    )
    print(f"\n[4/4] Fonds propres     -> {Path(chemin_fp).name}")
    print(f"      RWA total (convention outil) : {_md(rwa_total)} FCFA")
    print(f"      CET1                   : {_md(calibration['cet1'])} FCFA")
    print(f"      AT1                    : {_md(calibration['at1'])} FCFA")
    print(f"      Tier 2                 : {_md(calibration['tier2'])} FCFA")
    print(f"      Fonds propres globaux  : {_md(calibration['total'])} FCFA")
    print(f"      ratio CET1             : {calibration['ratio_cet1'] * 100:>11.2f} %")
    print(f"      ratio Tier 1           : {calibration['ratio_tier1'] * 100:>11.2f} %")
    print(f"      ratio de solvabilite   : {calibration['ratio'] * 100:>11.2f} %")

    print("\n      Repartition du RWA total :")
    for libelle, montant in (
        ("Credit", credit["rwa"]),
        ("Marche", marche["rwa_marche"]),
        ("Operationnel", rwa_operationnel),
    ):
        print(
            f"      {libelle:<16}{_md(montant)} FCFA"
            f"{montant / rwa_total * 100:>9.1f} %"
        )

    print("\n" + "=" * 78)
    print("Termine.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
