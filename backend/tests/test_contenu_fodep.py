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
    # entierement. La colonne « situation » reste vide, c'est une formule --
    # et depuis que les cases vides mais bordees sont conservees, elle figure
    # bien dans la ligne. Le niveau observe se cherche donc parmi les valeurs,
    # non a la derniere colonne.
    assert len(textes) >= 5
    valeurs = [texte for texte in textes if texte]
    assert valeurs[-1], "Le niveau observe de RA001 doit etre renseigne."


def _porte_quelque_chose(cellule) -> bool:
    return bool(
        cellule.texte or cellule.bordures or cellule.fond or cellule.image
    )


def test_aucune_ligne_ni_colonne_de_queue_sans_objet(contenu):
    """Le formulaire compte beaucoup de lignes de mise en page : les reporter
    donnerait un PDF de blancs.

    « Sans objet » ne veut pas dire « sans texte ». Une ligne bordee et
    vide est une case a renseigner restee vide : la retirer ferait perdre au
    tableau sa forme, et au lecteur l'endroit ou la valeur aurait du etre.
    Seules les lignes qui ne portent ni texte, ni trait, ni couleur sont
    ecartees.
    """

    for etat in contenu.etats:
        assert etat.largeurs, f"{etat.nom} : aucune largeur de colonne."
        assert len(etat.largeurs) <= COLONNES_MAX
        for ligne in etat.lignes:
            assert any(
                _porte_quelque_chose(cellule) for cellule in ligne.cellules
            ), f"{etat.nom} : ligne sans objet reportee."
            assert _porte_quelque_chose(
                ligne.cellules[-1]
            ), f"{etat.nom} : colonne de queue sans objet."
            couvertes = sum(
                max(cellule.colonnes, 1) for cellule in ligne.cellules
            )
            assert couvertes <= COLONNES_MAX, f"{etat.nom} : ligne trop large."


def test_la_page_de_garde_du_formulaire_est_rendue_entiere(contenu):
    """Le FODEP s'ouvre sur la couverture de la BCEAO, et elle doit y etre.

    Cette page ne porte qu'un seul texte, son titre, en troisieme colonne : tout
    le reste est de la couleur et une image. L'extraction s'arretait donc a la
    troisieme colonne et n'en tirait qu'un rectangle bleu, sans les bandes de
    couleur qui la traversent, sans le cartouche brun qui la ferme, et sans le
    logo — c'est-a-dire sans rien de ce a quoi on reconnait le formulaire.
    """

    garde = next(etat for etat in contenu.etats if etat.nom == "Page_de_garde")
    assert garde.nom == contenu.etats[0].nom, "La garde ouvre la declaration."
    assert not garde.paysage

    # Douze colonnes : le bandeau bleu, les bandes de couleur, le cartouche.
    assert len(garde.largeurs) == 12

    couleurs = {
        cellule.fond
        for ligne in garde.lignes
        for cellule in ligne.cellules
        if cellule.fond
    }
    assert {"83CAFF", "FFD320", "663300"} <= couleurs

    # Les bandes sont fusionnees sur toute la hauteur du bandeau : leur couleur
    # ne vit que sur la cellule de tete, et elles ne se coloraient donc que sur
    # leur premiere ligne.
    bandes = [
        ligne
        for ligne in garde.lignes
        if any(cellule.fond == "FFD320" for cellule in ligne.cellules)
    ]
    assert len(bandes) > 15, "Les bandes de couleur doivent courir sur la page."

    # Le logo de la BCEAO, ancre sur une plage de cellules.
    logos = [
        cellule
        for ligne in garde.lignes
        for cellule in ligne.cellules
        if cellule.image
    ]
    assert len(logos) == 1, "Le logo de la BCEAO doit accompagner la garde."
    assert logos[0].colonnes > 1, "Il est ancre sur toute la largeur du titre."

    titre = next(
        cellule
        for ligne in garde.lignes
        for cellule in ligne.cellules
        if cellule.texte.startswith("FORMULAIRE DE DECLARATION")
    )
    assert titre.taille and titre.taille >= 20


def test_le_perimetre_se_coche_en_symboles_et_non_en_nombres(contenu):
    """La feuille qui coche les etats a renseigner n'affiche aucun nombre.

    Elle en porte pourtant : 68 pour un etat exige, 32 sinon. Le classeur ne
    les montre pas — une mise en forme conditionnelle « jeu d'icones » y
    substitue une coche ou une croix et masque la valeur. Le PDF alignait donc
    trois colonnes de 68 et de 32 la ou le declarant lit des coches.
    """

    liste = next(
        etat for etat in contenu.etats if etat.nom.startswith("Liste_EP")
    )
    textes = {
        cellule.texte
        for ligne in liste.lignes
        for cellule in ligne.cellules
    }
    assert "68" not in textes and "32" not in textes

    # L'EP03 — les fonds propres sur base individuelle — n'est exige que sur
    # cette base ; l'EP05, son pendant consolide, sur les deux autres.
    ep03 = _ligne_du_code(liste, "EP03")
    ep05 = _ligne_du_code(liste, "EP05")
    assert ep03 is not None and ep05 is not None
    assert _textes(ep03)[2:5] == ["✓", "×", "×"]
    assert _textes(ep05)[2:5] == ["×", "✓", "✓"]

    # Une coche n'est plus un nombre : elle se centre, comme dans le classeur.
    coche = ep03.cellules[2]
    assert coche.centre and not coche.droite

    # Et elle porte la couleur qu'Excel donne a l'icone : sans elle, la feuille
    # sort en colonnes de coches et de croix noires, ou plus rien ne distingue
    # au premier coup d'oeil ce qui est exige de ce qui ne l'est pas.
    croix = ep03.cellules[3]
    assert coche.couleur and croix.couleur
    assert coche.couleur != croix.couleur
    # Et elle se nomme : le PDF la DESSINE plutot que d'ecrire un caractere.
    # Aucune police du document ne porte de coche grasse -- ni Aptos ni IBM
    # Plex Sans n'ont U+2714 --, et une coche maigre agrandie reste maigre,
    # sans rapport avec le symbole plein du classeur.
    assert (coche.icone, croix.icone) == ("valide", "refus")
    # Le caractere reste, pour un rendu qui ne saurait pas dessiner.
    assert (coche.texte, croix.texte) == ("✓", "×")


def test_les_largeurs_valent_pour_toute_la_plage_de_colonnes(contenu):
    """Le classeur regle ses colonnes par plages, pas une par une.

    Une seule entree « C:E » vaut pour les trois colonnes. Les lire par lettre
    ne servait que la premiere : « Individuelle » gardait ses 22 unites tandis
    que « Sous-consolidee » et « Consolidee » tombaient a la largeur par
    defaut, trop etroites pour leur propre intitule — coupe en plein mot. Le
    classeur compte cent soixante-dix plages de ce genre : c'est toute la mise
    en page du document qui en depend.
    """

    liste = next(
        etat for etat in contenu.etats if etat.nom.startswith("Liste_EP")
    )
    individuelle, sous_consolidee, consolidee = liste.largeurs[2:5]
    assert individuelle == sous_consolidee == consolidee

    # La colonne des intitules reste la plus large, comme dans le classeur.
    assert liste.largeurs[1] > individuelle


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


def test_les_etats_larges_ne_sont_plus_tronques(contenu):
    """Cinq etats portent du texte au-dela de la quatorzieme colonne.

    Le plafond valait 14 : l'attestation y perdait son champ
    « Etablissement », en colonne 20 du classeur, et l'EP07 la moitie de ses
    cinquante-quatre colonnes. Le PDF choisit desormais son format et sa
    reduction ; c'est a lui de faire tenir un etat large, pas a l'extraction de
    le couper.
    """

    par_nom = {etat.nom: etat for etat in contenu.etats}
    for nom in ("ADPE", "EP07", "EP29", "EP30", "EP31"):
        assert len(par_nom[nom].largeurs) > 14, nom

    adpe = par_nom["ADPE"]
    intitules = {
        cellule.texte.replace("\u00a0", " ").strip()
        for ligne in adpe.lignes
        for cellule in ligne.cellules
    }
    assert any(texte.startswith("ETABLISSEMENT") for texte in intitules)


def test_la_forme_du_formulaire_accompagne_ses_valeurs(contenu):
    """Fond, filets, alignement, taille et hauteur voyagent avec le texte.

    Sans eux, le PDF redessinait une grille grise uniforme en corps unique :
    la declaration s'y lisait, mais on n'y reconnaissait aucune page du
    formulaire, et rien ne distinguait une case a renseigner d'un intitule.
    """

    ep02 = next(etat for etat in contenu.etats if etat.nom == "EP02")
    cellules = [cellule for ligne in ep02.lignes for cellule in ligne.cellules]

    # Les cases a renseigner du formulaire sont teintees.
    assert any(cellule.fond == "FFF2CC" for cellule in cellules)
    # Son tableau est borde, ses titres ne le sont pas.
    assert any(cellule.bordures == "lrtb" for cellule in cellules)
    assert any(not cellule.bordures for cellule in cellules)
    # Ses en-tetes de colonne sont centres.
    assert any(cellule.centre for cellule in cellules)
    # La taille du classeur est conservee. L'EP02 est ecrit d'un bout a
    # l'autre en 12 ; c'est a l'echelle du formulaire entier que la hierarchie
    # se voit, du corps en 10 aux titres jusqu'a 22.
    assert all(cellule.taille for cellule in cellules)
    toutes = {
        cellule.taille
        for etat in contenu.etats
        for ligne in etat.lignes
        for cellule in ligne.cellules
        if cellule.taille
    }
    assert max(toutes) >= 2 * min(toutes)
    # Ses lignes portent la hauteur reglee dans le classeur.
    assert any(ligne.hauteur for ligne in ep02.lignes)


def test_l_orientation_et_les_en_tetes_viennent_du_classeur(contenu):
    """Le classeur regle lui-meme comment il s'imprime.

    Dix-neuf de ses etats sont en portrait ; les imprimer tous en paysage
    etirait leurs colonnes sur une page trois fois trop large. Et treize
    designent des lignes a repeter en haut de chaque page : une deuxieme page
    d'EP30 qui ne rappelle ni l'etat ni ses colonnes ne se lit pas.
    """

    portraits = [etat.nom for etat in contenu.etats if not etat.paysage]
    assert "EP02" in portraits
    assert 5 <= len(portraits) < len(contenu.etats)

    ep30 = next(etat for etat in contenu.etats if etat.nom == "EP30")
    entetes = [ligne for ligne in ep30.lignes if ligne.entete]
    assert entetes, "L'EP30 doit rappeler son en-tete a chaque page."
    # Elles sont en tete, et d'un seul tenant.
    assert all(ligne.entete for ligne in ep30.lignes[: len(entetes)])
