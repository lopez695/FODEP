"""Le contenu du FODEP se lit dans le classeur, sans le recalculer.

L'interface produit un PDF de la declaration. Elle ne peut pas le tirer du
classeur elle-meme : la bibliotheque Excel du poste de travail echoue a decoder
ce formulaire — « Null check operator used on a null value » des le decodage —
alors qu'openpyxl le relit sans peine, puisqu'il vient de l'ecrire.

L'extraction vit donc cote serveur, et ces tests verifient qu'elle rend bien le
classeur : ses codes DISPRU, ses intitules, ses montants, et rien qu'eux.
"""

from __future__ import annotations

from datetime import date

import pytest

from app.rapports.fodep.contenu import (
    COLONNES_MAX,
    ESPACE_FINE,
    _texte,
    contenu_fodep,
)


@pytest.fixture(scope="module")
def contenu():
    return contenu_fodep(date(2026, 6, 30))


def test_les_etats_du_formulaire_sont_rendus(contenu):
    """Une quarantaine d'etats, dont ceux que l'application alimente."""

    noms = {etat.nom for etat in contenu.etats}
    assert len(contenu.etats) >= 30
    for etat in ("EP01", "EP03", "EP20", "EP34"):
        assert etat in noms, etat


def _textes(ligne) -> list[str]:
    return [cellule.texte for cellule in ligne.cellules]


def _ligne_du_code(etat, code: str):
    return next(
        (ligne for ligne in etat.lignes if _textes(ligne)[:1] == [code]),
        None,
    )


def test_les_lignes_portent_codes_intitules_et_montants(contenu):
    """L'EP03 doit se relire comme le formulaire l'affiche."""

    ep03 = next(etat for etat in contenu.etats if etat.nom == "EP03")
    capital = _ligne_du_code(ep03, "FPI01")
    assert capital is not None, "La ligne FPI01 du capital social est absente."
    textes = _textes(capital)
    assert "Capital social" in textes[1]
    # Le montant est rendu lisible, pas brut : espaces de milliers, pas de
    # decimale inutile sur un entier de francs.
    assert textes[2]
    assert "." not in textes[2]
    # Et cadre a droite, comme dans le classeur.
    assert capital.cellules[2].droite


def test_la_forme_du_formulaire_est_conservee(contenu):
    """Le PDF doit etre le classeur imprime : sans les largeurs de colonnes ni
    les fusions, il deviendrait une grille de colonnes egales ou l'intitule d'un
    poste serait aussi etroit que la colonne d'un code."""

    ep01 = next(etat for etat in contenu.etats if etat.nom == "EP01")

    # Largeurs reelles, et une par colonne utilisee.
    assert len(ep01.largeurs) >= 7
    assert len(set(ep01.largeurs)) > 1, "Des colonnes de largeurs identiques."

    # Titre d'etat : une cellule fusionnee sur plusieurs colonnes, en gras.
    titre = ep01.lignes[0]
    assert titre.cellules[0].colonnes >= 3
    assert titre.cellules[0].gras

    # Intitule de section, fusionne lui aussi.
    section = next(
        ligne
        for ligne in ep01.lignes
        if any("Normes de solvabilite" in c.texte or "Normes de solvabilité" in c.texte
               for c in ligne.cellules)
    )
    assert max(cellule.colonnes for cellule in section.cellules) >= 3


def test_les_normes_de_l_ep01_portent_leur_niveau_observe(contenu):
    ep01 = next(etat for etat in contenu.etats if etat.nom == "EP01")
    ra001 = _ligne_du_code(ep01, "RA001")
    assert ra001 is not None
    textes = _textes(ra001)
    # Reference, niveau a respecter, niveau observe : le ratio CET1 se relit
    # entierement. La colonne « situation » reste vide, c'est une formule.
    assert len(textes) >= 5
    assert textes[-1], "Le niveau observe de RA001 doit etre renseigne."


def test_aucune_ligne_vide_ni_colonne_de_queue(contenu):
    """Le formulaire compte beaucoup de lignes de mise en page : les reporter
    donnerait un PDF de blancs, et des tableaux plus larges que la page."""

    for etat in contenu.etats:
        assert etat.largeurs, f"{etat.nom} : aucune largeur de colonne."
        assert len(etat.largeurs) <= COLONNES_MAX
        for ligne in etat.lignes:
            textes = _textes(ligne)
            assert any(textes), f"{etat.nom} : ligne vide reportee."
            assert textes[-1] != "", f"{etat.nom} : colonne de queue vide."
            couvertes = sum(
                max(cellule.colonnes, 1) for cellule in ligne.cellules
            )
            assert couvertes <= COLONNES_MAX, f"{etat.nom} : ligne trop large."


def test_les_reserves_de_lecture_accompagnent_le_contenu(contenu):
    """Elles doivent figurer sur le PDF : une declaration relue sans ses
    reserves se signe sans les connaitre."""

    assert isinstance(contenu.anomalies, list)
    assert contenu.date_arrete == date(2026, 6, 30)
    assert contenu.nom_fichier.endswith(".xlsx")


def test_une_formule_ne_se_rend_pas_comme_un_resultat():
    """Le classeur est ecrit sans etre evalue : « =SI(...) » n'est pas une
    valeur, et l'afficher ferait passer une mecanique pour un resultat."""

    assert _texte("=SI(G13>F13;\"NON CONFORME\";\"CONFORME\")") == ""
    assert _texte("CONFORME") == "CONFORME"


def test_les_nombres_se_rendent_a_la_francaise():
    # Espace fine insecable entre les milliers, virgule decimale : la police
    # embarquee dans le PDF sait dessiner les deux.
    assert _texte(49323.0) == f"49{ESPACE_FINE}323"
    assert _texte(0.1230) == "0,1230"
    assert _texte(0) == "0"
    assert _texte(True) == "OUI"
    assert _texte(None) == ""
