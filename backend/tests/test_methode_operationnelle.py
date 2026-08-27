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
    """Configure la base avec exactement trois exercices, puis rétablit l'état d'origine."""

    from app.risque_operationnel.services import calcul_as

    with database_manager.transaction() as connexion:
        sauvegarde = connexion.execute(
            "SELECT annee, ligne_metier, produit_brut_ligne FROM op_pnb_par_ligne"
        ).fetchall()

    reference = calcul_as().detail_par_annee
    assert reference, "l'essai suppose un exercice deja saisi"
    modele = {ligne.ligne_metier: ligne.pnb for ligne in reference[0].lignes}
    annee_connue = reference[0].annee
    ajoutees = (annee_connue - 2, annee_connue - 1)

    with database_manager.transaction() as connexion:
        connexion.execute("DELETE FROM op_pnb_par_ligne WHERE annee != ?", (annee_connue,))
        for annee in ajoutees:
            for ligne_metier, pnb in modele.items():
                connexion.execute(
                    """
                    INSERT INTO op_pnb_par_ligne(annee, ligne_metier, produit_brut_ligne)
                    VALUES (?, ?, ?)
                    """,
                    (annee, ligne_metier, pnb / 2),
                )
    try:
        yield annee_connue, ajoutees
    finally:
        with database_manager.transaction() as connexion:
            connexion.execute("DELETE FROM op_pnb_par_ligne")
            for annee, ligne_metier, pnb in sauvegarde:
                connexion.execute(
                    """
                    INSERT INTO op_pnb_par_ligne(annee, ligne_metier, produit_brut_ligne)
                    VALUES (?, ?, ?)
                    """,
                    (annee, ligne_metier, pnb),
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


def test_le_diviseur_de_l_approche_standard_reste_trois():
    """« (h) = moyenne des totaux c, e et g » : le diviseur ne suit pas la saisie.

    Le module divisait par le nombre d'exercices enregistres -- la regle de
    l'indicateur de base, dont le diviseur n est bien le nombre d'exercices a
    produit brut positif (art. 301). L'approche standard n'a pas cette
    provision : avec un seul exercice saisi, l'ecran affichait le triple de ce
    que l'EP23 transmis fait lire a la BCEAO sur ses propres colonnes.
    """

    from app.risque_operationnel.services import calcul_as

    calcul = calcul_as()
    exercices = [detail for detail in calcul.detail_par_annee if detail.renseignee]
    if len(exercices) >= 3:
        pytest.skip("la base porte deja les trois exercices")

    assert exercices, "l'essai suppose au moins un exercice saisi"
    assert calcul.k_as == pytest.approx(
        sum(detail.k_retenu for detail in exercices) / 3
    ), "les exercices manquants comptent pour zero, ils ne quittent pas la moyenne"


def test_un_exercice_deficitaire_reste_au_denominateur(trois_exercices):
    """Art. 309 : le total annuel est plancher a zero, l'exercice reste compte.

    Le plancher porte sur le numerateur, pas sur le diviseur : un exercice
    deficitaire ne doit pas alleger l'exigence des deux autres en sortant de
    la moyenne.
    """

    from app.risque_operationnel.services import calcul_as

    _, ajoutees = trois_exercices
    assert len(calcul_as().detail_par_annee) == 3

    deficitaire = min(ajoutees)
    with database_manager.transaction() as connexion:
        connexion.execute(
            "UPDATE op_pnb_par_ligne "
            "SET produit_brut_ligne = -produit_brut_ligne WHERE annee = ?",
            (deficitaire,),
        )

    calcul = calcul_as()
    annee_negative = next(
        detail for detail in calcul.detail_par_annee if detail.annee == deficitaire
    )
    assert annee_negative.k_total < 0
    assert annee_negative.k_retenu == 0.0

    autres = [
        detail.k_retenu
        for detail in calcul.detail_par_annee
        if detail.annee != deficitaire
    ]
    assert calcul.k_as == pytest.approx(sum(autres) / 3), (
        "trois exercices au denominateur, pas les deux qui restent positifs"
    )


def test_le_comparatif_bia_exclut_les_exercices_non_positifs():
    """Le comparatif du BIC porte le nom de l'AIB : il doit en suivre la regle.

    Art. 301 : la moyenne porte sur les produits bruts annuels POSITIFS, et le
    diviseur n est leur nombre. Le comparatif divisait par trois en comptant
    les exercices nuls ou negatifs -- sous le meme intitule « Approche
    indicateur de base », il annoncait donc un montant que l'onglet dedie
    contredisait, et l'ecart affiche face au CRR3 s'en trouvait fausse.
    """

    from app.risque_operationnel.services import (
        _compute_pnb_effectif,
        calcul_bic,
        get_aib_parametres,
    )

    resultat = calcul_bic()
    positifs = [
        pnb
        for pnb in (_compute_pnb_effectif(entree) for entree in resultat.inputs)
        if pnb > 0
    ]
    if not positifs:
        pytest.skip("aucun exercice a produit brut positif dans la base")

    attendu = sum(positifs) / len(positifs) * get_aib_parametres().alpha
    assert resultat.ofr_bia == pytest.approx(attendu)

    # Et le diviseur suit bien la saisie : trois exercices n'entrent dans la
    # moyenne que s'ils sont trois a etre positifs.
    if len(positifs) < 3:
        assert resultat.ofr_bia > sum(positifs) / 3 * get_aib_parametres().alpha


def test_l_approche_standard_refuse_un_quatrieme_exercice(trois_exercices):
    """Les trois exercices saisis, on modifie ou on retire -- on n'ajoute plus.

    L'Approche Standard porte sur exactement trois exercices. Au-delà, un
    exercice serait accepté par la base puis écarté du calcul sans que rien
    ne le dise.
    """

    from app.risque_operationnel.models import PnbParLigneCreate
    from app.risque_operationnel.services import (
        EXERCICES_MOYENNE_AS,
        calcul_as,
        list_exercices_as,
        upsert_pnb_ligne,
    )

    annee_connue, ajoutees = trois_exercices
    depart = [e.annee for e in list_exercices_as()]
    assert len(depart) == EXERCICES_MOYENNE_AS
    ligne = calcul_as().detail_par_annee[-1].lignes[0].ligne_metier

    candidate = min(depart) - 1
    with pytest.raises(ValueError, match="3 exercices"):
        upsert_pnb_ligne(
            candidate, ligne, PnbParLigneCreate(produit_brut_ligne=1000.0)
        )

    # Rien n'a été écrit, et l'Approche Standard porte toujours sur trois exercices.
    assert len(list_exercices_as()) == EXERCICES_MOYENNE_AS
    assert len(calcul_as().detail_par_annee) == EXERCICES_MOYENNE_AS


def test_les_trois_exercices_en_place_restent_modifiables(trois_exercices):
    """Le plafond porte sur l'ajout d'un millesime, pas sur la correction."""

    from app.risque_operationnel.models import PnbParLigneCreate
    from app.risque_operationnel.services import calcul_as, upsert_pnb_ligne

    _, ajoutees = trois_exercices
    annee = min(ajoutees)
    detail = next(d for d in calcul_as().detail_par_annee if d.annee == annee)
    ligne = detail.lignes[0].ligne_metier
    avant = detail.lignes[0].pnb

    vue = upsert_pnb_ligne(
        annee, ligne, PnbParLigneCreate(produit_brut_ligne=avant + 5000.0)
    )
    assert vue.produit_brut_ligne == pytest.approx(avant + 5000.0)


def test_le_millesime_d_un_exercice_se_corrige(trois_exercices):
    """Se tromper d'annee ne doit pas couter la ressaisie des huit lignes.

    Le millesime etait fige des l'enregistrement : le corriger passait par la
    suppression de l'exercice, donc par la perte du produit brut des huit
    lignes de metier. L'annee change maintenant seule, les montants suivent.
    """

    from app.risque_operationnel.services import calcul_as, renommer_exercice_as

    _, ajoutees = trois_exercices
    annee = min(ajoutees)
    avant = next(d for d in calcul_as().detail_par_annee if d.annee == annee)
    montants = {ligne.ligne_metier: ligne.pnb for ligne in avant.lignes}
    libre = min(ajoutees) - 5

    renommer_exercice_as(annee, libre)
    try:
        annees = [d.annee for d in calcul_as().detail_par_annee]
        assert annee not in annees
        assert libre in annees

        apres = next(d for d in calcul_as().detail_par_annee if d.annee == libre)
        assert {ligne.ligne_metier: ligne.pnb for ligne in apres.lignes} == montants
        assert apres.k_retenu == pytest.approx(avant.k_retenu)
    finally:
        renommer_exercice_as(libre, annee)


def test_le_millesime_ne_peut_pas_ecraser_un_exercice_existant(trois_exercices):
    """Renommer sur une annee deja saisie fusionnerait deux exercices."""

    from app.risque_operationnel.services import calcul_as, renommer_exercice_as

    annees = [d.annee for d in calcul_as().detail_par_annee]
    assert len(annees) == 3

    with pytest.raises(ValueError, match="deja saisi"):
        renommer_exercice_as(annees[0], annees[1])

    # Les trois exercices sont intacts.
    assert [d.annee for d in calcul_as().detail_par_annee] == annees


def test_le_millesime_de_l_indicateur_de_base_se_corrige_aussi():
    """Meme correction cote AIB, ou le champ annee etait fige lui aussi.

    Le formulaire desactivait le champ des qu'un exercice existait : corriger
    une annee obligeait a supprimer l'exercice, donc a perdre le produit brut
    et sa reference documentaire. Renommer les conserve.
    """

    from app.risque_operationnel.services import (
        list_pnb_annuel,
        renommer_exercice_aib,
    )

    exercices = list_pnb_annuel()
    assert exercices, "l'essai suppose au moins un exercice AIB saisi"

    avant = min(exercices, key=lambda a: a.annee)
    libre = avant.annee - 5
    assert libre not in {a.annee for a in exercices}

    renommer_exercice_aib(avant.annee, libre)
    try:
        vues = {a.annee: a for a in list_pnb_annuel()}
        assert avant.annee not in vues
        assert vues[libre].produit_brut_total == pytest.approx(
            avant.produit_brut_total
        )
        assert vues[libre].source_document == avant.source_document
    finally:
        renommer_exercice_aib(libre, avant.annee)

    # Et l'exercice a bien retrouve sa place.
    assert avant.annee in {a.annee for a in list_pnb_annuel()}


def test_le_tableau_de_bord_reprend_l_exigence_de_l_indicateur_de_base():
    """Les deux tuiles du dashboard sont celles de l'onglet AIB, au FCFA pres.

    Elles derivaient K d'un cumul de pertes d'incidents (« 15 % des pertes »),
    ce que l'article 301 ne dit nulle part : l'exigence porte sur le PRODUIT
    BRUT des trois derniers exercices, pas sur les pertes subies. Sous le meme
    intitule « capital minimum » et « RWA operationnel », les deux ecrans
    annoncaient des montants a plusieurs ordres de grandeur l'un de l'autre.
    """

    from app.risque_operationnel.services import calcul_aib, get_dashboard

    aib = calcul_aib()
    tuiles = get_dashboard().widget1

    assert tuiles.exigence_fonds_propres == pytest.approx(aib.k_ib)
    assert tuiles.apr_risque_op == pytest.approx(aib.apr_aib)
    # Et le RWA reste l'exigence multipliee par 12,5, pas divisee par un ratio.
    assert tuiles.apr_risque_op == pytest.approx(tuiles.exigence_fonds_propres * 12.5)


def test_le_statut_du_tableau_de_bord_signale_l_absence_d_exercice():
    """« Conforme » compare a zero ne pouvait jamais dire autre chose.

    Le statut valait « Conforme » si k_ib >= 0, ce qu'aucune exigence de fonds
    propres ne peut manquer : la tuile affichait la meme chose en toute
    circonstance, y compris sans le moindre exercice enregistre.
    """

    from app.risque_operationnel.services import calcul_aib, get_dashboard

    attendu = "À compléter" if calcul_aib().donnees_insuffisantes else "Conforme"
    assert get_dashboard().widget1.statut_reglementaire == attendu


def test_les_deux_tableaux_de_bord_annoncent_le_meme_rwa_operationnel(methode):
    """Le dashboard global et l'onglet Risque Operationnel, sur la meme ligne.

    Le global lit `apr_operationnel_retenu` (l'approche appliquee), l'onglet
    lisait un proxy bati sur les pertes d'incidents. Deux chemins, deux
    assiettes, un seul intitule : « RWA operationnel ».
    """

    from app.dashboard.services import get_dashboard_snapshot
    from app.risque_operationnel.services import (
        apr_operationnel_retenu,
        get_dashboard,
    )

    methode(False)  # l'indicateur de base est la methode appliquee
    metriques = {m.key: m.value for m in get_dashboard_snapshot().metrics}

    assert metriques["rwa_op"] == pytest.approx(apr_operationnel_retenu())
    assert metriques["rwa_op"] == pytest.approx(
        get_dashboard().widget1.apr_risque_op
    )


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

    with database_manager.transaction() as connexion:
        sauvegarde = connexion.execute(
            "SELECT annee, ligne_metier, produit_brut_ligne FROM op_pnb_par_ligne"
        ).fetchall()
        connexion.execute("DELETE FROM op_pnb_par_ligne")

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
        with database_manager.transaction() as connexion:
            connexion.execute("DELETE FROM op_pnb_par_ligne")
            for annee, l_metier, pnb in sauvegarde:
                connexion.execute(
                    "INSERT INTO op_pnb_par_ligne(annee, ligne_metier, produit_brut_ligne) VALUES (?, ?, ?)",
                    (annee, l_metier, pnb),
                )
