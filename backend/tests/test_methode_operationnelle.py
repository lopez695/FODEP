"""L'etablissement applique une methode de risque operationnel, pas les deux.

Le formulaire porte les deux approches : l'indicateur de base en EP21 et EP22,
la standard en EP23 et EP24. Une seule est renseignee, l'autre reste a zero, et
l'EP08 porte l'exigence sur la ligne correspondante.

Le choix vivait en base sans qu'aucun ecran ne permette de le poser, et
l'export ne le consultait pas : la declaration partait toujours en indicateur
de base, meme pour un etablissement autorise a l'approche standard.
"""

from __future__ import annotations

import pytest

from app.rapports.fodep.disposition import indexer_codes_dispru
from app.rapports.fodep.service import renseigner_classeur_fodep
from app.risque_operationnel.services import get_as_parametres
from database.connection import database_manager

COLONNE_APR_EP08 = 5


@pytest.fixture
def methode():
    """Pose la methode, et rend a la base celle qu'elle portait."""

    depart = get_as_parametres().as_autorisee

    def poser(standard: bool) -> None:
        with database_manager.transaction() as connexion:
            connexion.execute(
                "UPDATE op_parametres_as SET as_autorisee = ? WHERE id = 1",
                (int(standard),),
            )

    yield poser
    poser(depart)


def _valeur(classeur, feuille: str, code: str, colonne: int):
    lignes = indexer_codes_dispru(classeur[feuille])
    return classeur[feuille].cell(row=lignes[code], column=colonne).value


def _somme_des_cases(classeur, feuille: str, code: str, colonnes: range) -> float:
    lignes = indexer_codes_dispru(classeur[feuille])
    total = 0.0
    for colonne in colonnes:
        valeur = classeur[feuille].cell(row=lignes[code], column=colonne).value
        if isinstance(valeur, (int, float)) and not isinstance(valeur, bool):
            total += float(valeur)
    return total


def test_l_indicateur_de_base_porte_l_exigence_sur_sa_ligne(methode):
    methode(False)
    produit = renseigner_classeur_fodep()
    try:
        classeur = produit.classeur
        apr = _valeur(classeur, "EP08", "RO010", COLONNE_APR_EP08)
        assert apr, "l'EP08 doit porter l'APR operationnel sur la ligne RO010"
        # L'approche standard n'est pas retenue : sa ligne reste a zero.
        assert _valeur(classeur, "EP08", "RO037", COLONNE_APR_EP08) == 0
        assert _valeur(classeur, "EP08", "APR03", COLONNE_APR_EP08) == apr
        # Et l'EP23 ne declare rien.
        assert _somme_des_cases(classeur, "EP23", "RO037", range(3, 12)) == 0
    finally:
        produit.classeur.close()


def test_l_approche_standard_renseigne_l_ep23_et_vide_l_ep21(methode):
    """Le choix bascule l'etat renseigne, la ligne de l'EP08 et le total."""

    methode(True)
    produit = renseigner_classeur_fodep()
    try:
        classeur = produit.classeur

        # L'EP23 conclut : une exigence, et l'APR qui en decoule.
        exigence = _valeur(classeur, "EP23", "RO036", 9)
        apr_ep23 = _valeur(classeur, "EP23", "RO037", 9)
        assert exigence, "l'EP23 doit porter l'exigence de fonds propres"
        # « (i) = h x 12,5 », comme le dit le formulaire.
        assert apr_ep23 == pytest.approx(exigence * 12.5, rel=0.02)

        # L'EP08 porte l'exigence sur la ligne de l'approche standard, et
        # l'indicateur de base y reste a zero.
        assert _valeur(classeur, "EP08", "RO037", COLONNE_APR_EP08) == apr_ep23
        assert _valeur(classeur, "EP08", "RO010", COLONNE_APR_EP08) == 0
        assert _valeur(classeur, "EP08", "APR03", COLONNE_APR_EP08) == apr_ep23

        # L'EP21 n'est plus renseigne : l'etablissement n'applique pas les deux.
        assert _somme_des_cases(classeur, "EP21", "RO010", range(3, 10)) == pytest.approx(
            0.15, abs=0.001
        ), "seul l'alpha du formulaire subsiste sur la ligne de l'EP21"
    finally:
        produit.classeur.close()


@pytest.fixture
def trois_exercices():
    """Ajoute deux exercices de produit brut par ligne, puis les retire."""

    from app.risque_operationnel.services import calcul_as

    reference = calcul_as().detail_par_annee
    assert reference, "l'essai suppose un exercice deja saisi"
    modele = {ligne.ligne_metier: ligne.pnb for ligne in reference[0].lignes}
    annee_connue = reference[0].annee
    ajoutees = (annee_connue - 2, annee_connue - 1)

    with database_manager.transaction() as connexion:
        for annee in ajoutees:
            for ligne_metier, pnb in modele.items():
                connexion.execute(
                    """
                    INSERT INTO op_pnb_par_ligne(annee, ligne_metier, produit_brut_ligne)
                    VALUES (?, ?, ?)
                    """,
                    (annee, ligne_metier, pnb / 2),
                )
    yield annee_connue, ajoutees
    with database_manager.transaction() as connexion:
        connexion.execute(
            "DELETE FROM op_pnb_par_ligne WHERE annee IN (?, ?)", ajoutees
        )


def test_l_exigence_est_la_moyenne_des_trois_exercices(methode, trois_exercices):
    """La regle de Bale, et celle que le formulaire ecrit noir sur blanc.

    Le module ne calculait que sur l'exercice le plus recent. Tant qu'un seul
    etait saisi, les deux revenaient au meme ; des le deuxieme, cet ecran et la
    declaration transmise a la BCEAO se seraient contredits sur la meme
    exigence -- l'un affichant le dernier exercice, l'autre leur moyenne.
    """

    from app.risque_operationnel.services import calcul_as

    calcul = calcul_as()
    assert len(calcul.detail_par_annee) == 3

    retenus = [detail.k_retenu for detail in calcul.detail_par_annee]
    assert calcul.k_as == pytest.approx(sum(retenus) / 3)
    # Les deux exercices ajoutes valent la moitie du troisieme : la moyenne
    # vaut donc les deux tiers du plus recent.
    assert calcul.k_as == pytest.approx(max(retenus) * 2 / 3, rel=1e-6)

    # Et l'EP23 declare cette moyenne, pas le dernier exercice.
    methode(True)
    produit = renseigner_classeur_fodep()
    try:
        classeur = produit.classeur
        feuille = classeur["EP23"]
        lignes = indexer_codes_dispru(feuille)
        # Les trois exercices occupent leurs trois paires de colonnes.
        for colonne in (5, 7, 9):
            assert feuille.cell(row=lignes["RO035"], column=colonne).value
        exigence = feuille.cell(row=lignes["RO036"], column=9).value
        dernier = feuille.cell(row=lignes["RO035"], column=9).value
        assert exigence < dernier, (
            "l'exigence doit etre la moyenne des trois exercices, "
            "donc inferieure au plus eleve d'entre eux"
        )
    finally:
        produit.classeur.close()


def test_l_ep23_ventile_les_huit_lignes_de_metier(methode):
    """Chaque ligne de metier porte son produit brut et son exigence.

    C'est ce qui distingue l'approche standard de l'indicateur de base : le
    produit brut n'est plus global, il se ventile en huit lignes, chacune avec
    son beta reglementaire. Le module Risque Operationnel tient deja les deux.
    """

    methode(True)
    produit = renseigner_classeur_fodep()
    try:
        classeur = produit.classeur
        feuille = classeur["EP23"]
        lignes = indexer_codes_dispru(feuille)

        # Les huit lignes de metier du bloc B, de RO027 a RO034.
        codes = [f"RO{numero:03d}" for numero in range(27, 35)]
        assert all(code in lignes for code in codes)

        # L'etat doit se boucler : le total du dernier exercice est la somme
        # des huit lignes de metier. C'est ce qu'un controleur verifie, et le
        # seul rapport qui tienne a l'echelle du formulaire -- exprime en
        # millions, un produit brut de 1 million multiplie par son beta
        # s'arrondit a zero sans que le calcul soit faux.
        somme_brut = somme_exigence = 0.0
        renseignees = 0
        for code in codes:
            rang = lignes[code]
            brut = feuille.cell(row=rang, column=8).value or 0
            exigence = feuille.cell(row=rang, column=9).value or 0
            somme_brut += float(brut)
            somme_exigence += float(exigence)
            if brut:
                renseignees += 1

        assert renseignees, "aucune ligne de metier n'a ete declaree"
        total_brut = feuille.cell(row=lignes["RO035"], column=8).value
        total_exigence = feuille.cell(row=lignes["RO035"], column=9).value
        # Un million de tolerance : chaque ligne est arrondie pour elle-meme.
        assert abs(float(total_brut) - somme_brut) <= len(codes)
        assert abs(float(total_exigence) - somme_exigence) <= len(codes)

        # Et l'exigence retenue n'est jamais negative : « total ou zero, le
        # plus eleve etant retenu », dit le formulaire.
        assert float(total_exigence) >= 0
    finally:
        produit.classeur.close()


def test_enregistrer_un_exercice_ne_retire_pas_les_autres():
    """Les trois exercices de l'approche standard doivent pouvoir coexister.

    `upsert_pnb_ligne` effacait toutes les autres annees a chaque
    enregistrement -- « l'Approche Standard ne conserve qu'UN exercice »,
    disait son commentaire. La moyenne sur trois exercices qu'exigent Bale, la
    notice (§ 9.2) et la ligne RO035 de l'EP23 etait donc inatteignable : la
    declaration transmise a la BCEAO ne portait jamais que sur l'exercice
    saisi en dernier, sans que rien ne signale les deux autres comme perdus.
    """

    from app.risque_operationnel.models import PnbParLigneCreate
    from app.risque_operationnel.services import (
        delete_pnb_lignes,
        get_pnb_lignes,
        upsert_pnb_ligne,
    )

    # Deux millesimes hors de portee des donnees reelles, retires ensuite.
    ancien, recent = 2001, 2002
    ligne_metier = "Banque de détail"
    try:
        upsert_pnb_ligne(ancien, ligne_metier, PnbParLigneCreate(produit_brut_ligne=100.0))
        upsert_pnb_ligne(recent, ligne_metier, PnbParLigneCreate(produit_brut_ligne=200.0))

        conserve = get_pnb_lignes(ancien)
        assert conserve, (
            "enregistrer l'exercice suivant a efface le precedent : "
            "la moyenne sur trois exercices redevient inatteignable"
        )
        assert conserve[0].produit_brut_ligne == pytest.approx(100.0)
        assert get_pnb_lignes(recent)[0].produit_brut_ligne == pytest.approx(200.0)

        # Et un exercice saisi par erreur se retire, seul.
        delete_pnb_lignes(ancien)
        assert not get_pnb_lignes(ancien)
        assert get_pnb_lignes(recent), "le retrait a emporte l'exercice voisin"
    finally:
        delete_pnb_lignes(ancien)
        delete_pnb_lignes(recent)
