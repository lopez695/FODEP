"""Chaque compte travaille dans sa propre base, sans voir celle des autres.

L'isolation ne repose pas sur un filtre applique aux requetes SQL : il
suffirait d'en oublier une pour ouvrir une fuite. Elle repose sur des fichiers
distincts. Ces tests verifient qu'une ecriture faite sous un compte reste
invisible sous un autre.
"""

from __future__ import annotations

import pytest

from app.auth.espaces import chemin_espace, nom_de_fichier, preparer_espace
from database.connection import (
    DATABASE_PATH,
    base_commune,
    database_manager,
    espace_courant,
    restaurer_espace,
    utiliser_espace,
)


def _compter_expositions() -> int:
    with database_manager.read_connection() as connexion:
        return int(
            connexion.execute("SELECT COUNT(*) FROM expositions").fetchone()[0]
        )


def _compter_contreparties() -> int:
    with database_manager.read_connection() as connexion:
        return int(
            connexion.execute("SELECT COUNT(*) FROM contreparties").fetchone()[0]
        )


@pytest.mark.parametrize(
    ("saisi", "attendu"),
    [
        ("Pascal", "pascal"),
        ("marie.kone@banque.ci", "marie_kone_banque_ci"),
        # Un identifiant hostile ne doit pas designer un fichier hors du
        # dossier des espaces.
        ("../../etc/passwd", "etc_passwd"),
        ("   ", "compte"),
    ],
)
def test_un_identifiant_ne_peut_pas_sortir_du_dossier(saisi, attendu):
    assert nom_de_fichier(saisi) == attendu
    assert chemin_espace(saisi).parent == chemin_espace("autre").parent


def test_ce_qu_un_compte_saisit_reste_chez_lui():
    """Le coeur de l'isolation : une ecriture ne franchit pas les espaces."""

    espace_a = preparer_espace("compte_essai_a")
    espace_b = preparer_espace("compte_essai_b")
    assert espace_a != espace_b

    # Les espaces survivent d'une execution a l'autre : le test efface sa
    # propre trace avant d'ecrire, sans quoi il echouerait au second passage
    # sur une contrainte d'unicite.
    for espace in (espace_a, espace_b):
        jeton = utiliser_espace(espace)
        try:
            with database_manager.transaction() as connexion:
                connexion.execute(
                    "DELETE FROM contreparties WHERE id = 'CP_ESSAI'"
                )
        finally:
            restaurer_espace(jeton)

    jeton = utiliser_espace(espace_a)
    try:
        avant_a = _compter_contreparties()
        with database_manager.transaction() as connexion:
            connexion.execute(
                """
                INSERT INTO contreparties(
                    id, nom, pays, notation_pays, categorie_standard,
                    categorie_prudentielle, notation, cree_le, modifie_le
                )
                VALUES('CP_ESSAI', 'Contrepartie A', 'Togo', 'BB',
                       'Entreprises', 'Entreprises', 'BBB',
                       '2026-01-01', '2026-01-01')
                """
            )
        chez_a = _compter_contreparties()
    finally:
        restaurer_espace(jeton)

    assert chez_a == avant_a + 1

    jeton = utiliser_espace(espace_b)
    try:
        with database_manager.read_connection() as connexion:
            presente_chez_b = connexion.execute(
                "SELECT COUNT(*) FROM contreparties WHERE id = 'CP_ESSAI'"
            ).fetchone()[0]
    finally:
        restaurer_espace(jeton)

    assert presente_chez_b == 0, (
        "Une contrepartie saisie dans un espace apparait dans un autre : les "
        "comptes partagent la meme base."
    )


def test_les_comptes_restent_dans_la_base_commune():
    """Sans cette regle, se connecter deviendrait impossible.

    Les comptes n'appartiennent a aucun espace : ils doivent rester lisibles
    quel que soit l'espace actif au moment de la requete.
    """

    espace = preparer_espace("compte_essai_d")
    jeton = utiliser_espace(espace)
    try:
        assert espace_courant() == espace
        with base_commune():
            assert espace_courant() == DATABASE_PATH
        # La bascule est bien rendue a la sortie du bloc.
        assert espace_courant() == espace
    finally:
        restaurer_espace(jeton)


def test_hors_requete_la_base_commune_s_applique():
    # Application de bureau et taches de fond : aucun espace n'est pose.
    assert espace_courant() == DATABASE_PATH


def test_un_espace_neuf_est_entierement_vide():
    """Un nouvel arrivant ne doit trouver aucune donnee, d'aucun module.

    Un espace pre-rempli du jeu de demonstration laisse croire a un
    portefeuille reel : credit, marche et operationnel doivent partir de zero.
    """

    import sqlite3

    from app.auth.espaces import _TABLES_REFERENCE

    espace = preparer_espace("compte_neuf_essai")
    connexion = sqlite3.connect(espace)
    try:
        tables = [
            str(ligne[0])
            for ligne in connexion.execute(
                "SELECT name FROM sqlite_master "
                "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
            )
        ]
        peuplees = {
            table: connexion.execute(
                f'SELECT COUNT(*) FROM "{table}"'
            ).fetchone()[0]
            for table in tables
            if table not in _TABLES_REFERENCE
        }
    finally:
        connexion.close()

    restantes = {table: n for table, n in peuplees.items() if n}
    assert not restantes, (
        f"Ces tables portent encore des donnees dans un espace neuf : "
        f"{restantes}. Une table de donnees ajoutee depuis doit etre videe, "
        "ou declaree comme table de reference si elle porte le dispositif."
    )


def test_le_dispositif_prudentiel_survit_a_la_purge():
    """Vider les grilles rendrait tout calcul impossible."""

    import sqlite3

    espace = preparer_espace("compte_neuf_essai")
    connexion = sqlite3.connect(espace)
    try:
        for table in ("risk_weight_references", "ccf_references", "rating_references"):
            n = connexion.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            assert n > 0, (
                f"La table de reference « {table} » est vide : aucune "
                "ponderation ne pourrait plus etre determinee."
            )
    finally:
        connexion.close()


def test_un_espace_neuf_expose_les_referentiels():
    """Les grilles doivent survivre a la purge ET etre lisibles par l'ecran.

    Elles existent sous deux noms dans la base : celui d'avant le renommage
    de 2021 et le nom francais actuel. Les deux doivent etre conserves, sinon
    l'ecran Referentiels d'un nouvel arrivant reste vide.
    """

    from database.repositories.referential_repository import referential_repository

    espace = preparer_espace("compte_referentiels_essai")
    jeton = utiliser_espace(espace)
    try:
        assert referential_repository.list_risk_weight_references(), (
            "Aucune ponderation visible dans un espace neuf."
        )
        assert referential_repository.list_ccf_references()
        assert referential_repository.list_rating_references()
    finally:
        restaurer_espace(jeton)


def test_l_orm_ne_porte_que_des_donnees_de_reference():
    """Garde-fou sur le seul chemin qui echappe a l'isolation.

    Le moteur SQLAlchemy est lie a la base commune au chargement du module :
    il ne suit pas l'espace de la requete. C'est sans consequence tant qu'il
    ne sert que le dispositif prudentiel, identique pour tous. Le jour ou un
    modele porterait des donnees d'utilisateur, celles-ci seraient lues dans
    la base commune et partagees par tous les comptes.
    """

    from app.auth.espaces import _TABLES_REFERENCE
    from database.orm import Base

    tables_orm = set(Base.metadata.tables)
    hors_reference = tables_orm - set(_TABLES_REFERENCE)
    assert not hors_reference, (
        f"Ces tables sont lues par l'ORM, donc dans la base commune, alors "
        f"qu'elles ne sont pas declarees comme reference : {hors_reference}. "
        "Elles seraient partagees entre tous les comptes."
    )


def test_un_espace_neuf_n_herite_d_aucune_exigence_de_marche():
    """Zero exposition doit donner zero exigence, dans tous les modules.

    L'exigence du risque de marche et le portefeuille de marche vivent dans
    `metadonnees_app`, aux cotes de cles purement techniques. Conserver la
    table entiere faisait apparaitre 204 Md de RWA marche -- et un capital
    requis de 18,42 Md -- dans un espace vide de toute exposition.
    """

    import sqlite3

    from app.auth.espaces import _CLES_METADONNEES_TECHNIQUES

    espace = preparer_espace("compte_marche_essai")
    connexion = sqlite3.connect(espace)
    try:
        cles = {
            str(ligne[0])
            for ligne in connexion.execute("SELECT cle FROM metadonnees_app")
        }
    finally:
        connexion.close()

    restantes = cles - set(_CLES_METADONNEES_TECHNIQUES)
    assert not restantes, (
        f"Ces metadonnees sont heritees de la demonstration : {restantes}. "
        "Une cle porteuse de donnees doit etre purgee, une cle technique "
        "declaree explicitement."
    )


def test_le_recalcul_ne_repart_pas_de_zero_dans_un_espace_neuf():
    """La version des regles reste, sinon chaque espace rejoue un recalcul."""

    import sqlite3

    espace = preparer_espace("compte_marche_essai")
    connexion = sqlite3.connect(espace)
    try:
        valeur = connexion.execute(
            "SELECT valeur FROM metadonnees_app WHERE cle = ?",
            ("exposure_calc_rules_version",),
        ).fetchone()
    finally:
        connexion.close()

    assert valeur is not None and str(valeur[0]).strip()
