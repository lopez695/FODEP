# -*- coding: utf-8 -*-
"""Estimation de l'exigence de fonds propres au titre du risque de marché.

Portage Python de `calculateMarketPrudentialCapital`
(frontend/lib/modules/risque_marche/services/market_data_import_store.dart) :
risque de taux (spécifique + général par échéancier), risque actions
(spécifique + général) et risque de change. Sert uniquement à calibrer les
fonds propres du quatrième modèle — l'outil reste seul juge du chiffre final.
"""

from __future__ import annotations

import math
from datetime import date

from _referentiels import TAUX_XOF

DATE_REF = date(2026, 6, 30)

_PAYS_UEMOA_ISO3 = {"BEN", "BFA", "CIV", "GNB", "MLI", "NER", "SEN", "TGO"}

_ISO3 = {
    "Cote d'Ivoire": "CIV", "Senegal": "SEN", "Benin": "BEN",
    "Burkina Faso": "BFA", "Mali": "MLI", "Niger": "NER", "Togo": "TGO",
    "Guinee-Bissau": "GNB", "France": "FRA", "Cameroun": "CMR",
    "Arabie saoudite": "SAU", "Etats-Unis": "USA",
}

_MOTS_SOUVERAINS = (
    "tresor", "etat", "republique", "souverain", "ministere",
)


def _plier(texte: str) -> str:
    remplacements = {
        "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
        "î": "i", "ï": "i", "ô": "o", "ö": "o", "ù": "u", "û": "u", "ü": "u",
        "ç": "c", "’": " ", "'": " ",
    }
    resultat = texte.lower()
    for source, cible in remplacements.items():
        resultat = resultat.replace(source, cible)
    return resultat


def _est_negociation(intention: str) -> bool:
    normalise = _plier(intention)
    if not normalise:
        return True
    if any(mot in normalise for mot in ("trading", "hft", "fvtpl", "negociation", "transaction")):
        return True
    if any(mot in normalise for mot in ("htm", "afs", "fvoci", "amorti", "jusqu", "disponible", "detenu", "bancaire")):
        return False
    return True


def _qualite(notation: str) -> str:
    note = (notation or "").strip().upper().replace(" ", "")
    if not note or "NONNOTE" in note or "NONNOTÉ" in note or note == "NR":
        return "unrated"
    if note in ("<B-", "SOUSB-") or note.startswith("CCC") or note.startswith("CC") or note in ("C", "D"):
        return "belowB"
    if note in ("AAA", "AA+", "AA", "AA-"):
        return "aaaToAa"
    if note in ("A+", "A", "A-", "BBB+", "BBB", "BBB-"):
        return "aToBbb"
    if note in ("BB+", "BB", "BB-", "B+", "B", "B-"):
        return "bbToB"
    return "unrated"


def _mois_residuels(echeance_iso: str) -> float:
    annee, mois, jour = (int(part) for part in echeance_iso.split("-"))
    jours = (date(annee, mois, jour) - DATE_REF).days
    if jours <= 0:
        return 0.0
    return math.ceil(jours / 30.44)


def _est_souverain(ligne: dict) -> bool:
    texte = _plier(
        " ".join([
            ligne["Emetteur"], ligne["Type d'instrument"],
            ligne["Code type d'instrument"], ligne["Pays émetteur"],
        ])
    )
    return any(mot in texte for mot in _MOTS_SOUVERAINS)


def _est_eligible(ligne: dict, qualite: str) -> bool:
    if qualite in ("aaaToAa", "aToBbb"):
        return True
    texte = _plier(f"{ligne['Emetteur']} {ligne['Type d\'instrument']}")
    return any(
        mot in texte
        for mot in ("boad", "bceao", "bad", "bid", "bird", "banque mondiale",
                    "multilaterale", "organisme public")
    )


def _poids_specifique(ligne: dict) -> float:
    qualite = _qualite(ligne["La pire notation externe"])
    annees = _mois_residuels(ligne["Date d'échéance"]) / 12.0
    souverain = _est_souverain(ligne)
    iso3 = _ISO3.get(ligne["Pays émetteur"], "")

    if souverain and iso3 in _PAYS_UEMOA_ISO3 and ligne["Devise"] == "XOF":
        return 0.0

    if souverain:
        if qualite == "aaaToAa":
            return 0.0
        if qualite == "aToBbb":
            return 0.0025 if annees < 0.5 else (0.01 if annees <= 2.0 else 0.016)
        if qualite == "bbToB":
            return 0.08
        if qualite == "belowB":
            return 0.12
        return 0.08

    if _est_eligible(ligne, qualite):
        if qualite == "bbToB":
            return 0.08
        return 0.0025 if annees < 0.5 else (0.01 if annees <= 2.0 else 0.016)

    if qualite == "aaaToAa":
        return 0.0
    if qualite == "belowB":
        return 0.12
    return 0.08


_SEUILS = [
    1 / 12, 3 / 12, 6 / 12, 1.0, 2.0, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0, 20.0,
    float("inf"),
]
_POIDS = [
    0.0, 0.0020, 0.0040, 0.0070, 0.0125, 0.0175, 0.0225, 0.0275, 0.0325,
    0.0375, 0.0450, 0.0525, 0.0600,
]


def _tranche_generale(annees: float):
    index = next(
        (position for position, seuil in enumerate(_SEUILS) if annees <= seuil),
        len(_SEUILS) - 1,
    )
    zone = 1 if index <= 3 else (2 if index <= 8 else 3)
    return index, zone, _POIDS[index]


def _position_obligation(ligne: dict) -> float:
    """Valeur de position prudentielle : capital initial converti en XOF."""
    if _mois_residuels(ligne["Date d'échéance"]) <= 0:
        return 0.0
    return ligne["Capital initial"] * TAUX_XOF.get(ligne["Devise"], 1.0)


def _apparier(residus, gauche: int, droite: int, facteur: float) -> float:
    valeur_gauche, valeur_droite = residus[gauche], residus[droite]
    if valeur_gauche == 0 or valeur_droite == 0:
        return 0.0
    if (valeur_gauche > 0) == (valeur_droite > 0):
        return 0.0
    apparie = min(abs(valeur_gauche), abs(valeur_droite))
    residus[gauche] += apparie if valeur_gauche < 0 else -apparie
    residus[droite] += apparie if valeur_droite < 0 else -apparie
    return apparie * facteur


def exigence_taux(obligations) -> dict:
    negociation = [
        ligne for ligne in obligations
        if _est_negociation(ligne["Intention comptable"])
    ]

    specifique = 0.0
    positions_totales = 0.0
    balances = {}
    tranches = {}

    for ligne in negociation:
        position = _position_obligation(ligne)
        if position <= 0:
            continue
        positions_totales += position
        specifique += position * _poids_specifique(ligne)

        annees = max(0.0, _mois_residuels(ligne["Date d'échéance"]) / 12.0)
        index, zone, poids = _tranche_generale(annees)
        tranches[index] = (zone, poids)
        pondere = position * poids  # toutes les positions du jeu sont longues
        if pondere == 0:
            continue
        devise = ligne["Devise"]
        balances.setdefault(devise, {}).setdefault(index, [0.0, 0.0])
        balances[devise][index][0] += pondere

    general = 0.0
    for tranches_devise in balances.values():
        zone_long = [0.0, 0.0, 0.0]
        zone_short = [0.0, 0.0, 0.0]
        for index, (longue, courte) in tranches_devise.items():
            zone, _poids = tranches[index]
            apparie = min(longue, courte)
            general += apparie * 0.10
            residu = longue - courte
            position_zone = min(max(zone - 1, 0), 2)
            if residu >= 0:
                zone_long[position_zone] += residu
            else:
                zone_short[position_zone] += abs(residu)

        residus = [0.0, 0.0, 0.0]
        facteurs_intra = [0.40, 0.30, 0.30]
        for position_zone in range(3):
            apparie = min(zone_long[position_zone], zone_short[position_zone])
            general += apparie * facteurs_intra[position_zone]
            residus[position_zone] = zone_long[position_zone] - zone_short[position_zone]

        general += _apparier(residus, 0, 1, 0.40)
        general += _apparier(residus, 1, 2, 0.40)
        general += _apparier(residus, 0, 2, 1.00)
        general += abs(sum(residus))

    return {
        "specifique": specifique,
        "general": general,
        "positions": positions_totales,
        "lignes_negociation": len(negociation),
    }


def exigence_actions(actions) -> dict:
    negociation = [
        ligne for ligne in actions
        if _est_negociation(ligne["Intention comptable"])
    ]
    net_par_emetteur = {}
    liquide_par_emetteur = {}
    net_par_marche = {}
    brut = 0.0

    for ligne in negociation:
        position = (
            ligne["Quantité"] * ligne["Cours actuel"]
            * TAUX_XOF.get(ligne["Devise"], 1.0)
        )
        if position <= 0:
            continue
        brut += position
        emetteur = ligne["Émetteur / Société"]
        net_par_emetteur[emetteur] = net_par_emetteur.get(emetteur, 0.0) + position
        if ligne["Liquide et diversifié (Oui/Non)"] == "Oui":
            liquide_par_emetteur[emetteur] = True
        marche = _ISO3.get(ligne["Pays / marché"], ligne["Devise"])
        net_par_marche[marche] = net_par_marche.get(marche, 0.0) + position

    specifique = sum(
        abs(valeur) * (0.04 if liquide_par_emetteur.get(emetteur) else 0.08)
        for emetteur, valeur in net_par_emetteur.items()
    )
    general = sum(abs(valeur) for valeur in net_par_marche.values()) * 0.08

    return {
        "specifique": specifique,
        "general": general,
        "brut": brut,
        "lignes_negociation": len(negociation),
    }


def exigence_change(obligations, actions) -> dict:
    """8 % de la position nette globale en devises — périmètre établissement
    (portefeuilles bancaire et de négociation confondus)."""
    net_par_devise = {}
    for ligne in obligations:
        devise = ligne["Devise"]
        if devise == "XOF":
            continue
        position = _position_obligation(ligne)
        if position <= 0:
            continue
        net_par_devise[devise] = net_par_devise.get(devise, 0.0) + position
    for ligne in actions:
        devise = ligne["Devise"]
        if devise == "XOF":
            continue
        position = (
            ligne["Quantité"] * ligne["Cours actuel"] * TAUX_XOF.get(devise, 1.0)
        )
        if position <= 0:
            continue
        net_par_devise[devise] = net_par_devise.get(devise, 0.0) + position

    longues = sum(valeur for valeur in net_par_devise.values() if valeur >= 0)
    courtes = sum(abs(valeur) for valeur in net_par_devise.values() if valeur < 0)
    position_nette = max(longues, courtes)
    return {
        "position_nette": position_nette,
        "exigence": position_nette * 0.08,
        "detail": net_par_devise,
    }


def exigence_totale(obligations, actions) -> dict:
    taux = exigence_taux(obligations)
    equity = exigence_actions(actions)
    change = exigence_change(obligations, actions)
    capital = (
        taux["specifique"] + taux["general"]
        + equity["specifique"] + equity["general"]
        + change["exigence"]
    )
    return {
        "taux": taux,
        "actions": equity,
        "change": change,
        "capital_requis": capital,
        "rwa_marche": capital * 12.5,
    }
