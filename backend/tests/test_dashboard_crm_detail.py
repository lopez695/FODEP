"""Le portefeuille servi au tableau de bord porte le detail de chaque CRM.

Sans ces champs, le detail « Expositions par CRM » ne pouvait montrer ni la
surete retenue, ni le garant, ni l'effet reel de la garantie : une garantie
qui alourdit la ponderation y ressemblait a une couverture ordinaire.
"""

from __future__ import annotations

import pytest

from app.dashboard.services import get_dashboard_snapshot


@pytest.fixture(scope="module")
def rows():
    return get_dashboard_snapshot().portfolio_overview


def _bucket(rows, crm_type):
    return [row for row in rows if row.crm_type == crm_type]


def test_crm_financee_expose_la_surete_et_sa_decote(rows):
    financees = _bucket(rows, "CRM financee")
    if not financees:
        pytest.skip("Aucune CRM financee dans ce jeu de donnees.")
    for row in financees:
        assert row.collateral_value > 0, (
            f"{row.id} : une surete financee sans valeur de collateral ne "
            "peut pas justifier la reduction d'exposition."
        )
        if not row.crm_eligible:
            # Une surete inegible ne reduit rien : la colonne « surete
            # retenue » doit rester a zero, sinon l'ecran affiche une
            # couverture que le calcul n'accorde pas.
            assert row.collateral_value_after_haircut == 0
            continue
        # Vas = C x (1 - Hc - Hfx) : la valeur retenue decoule de la decote
        # affichee, sinon les deux colonnes racontent deux histoires.
        attendu = row.collateral_value * (1 - row.collateral_haircut)
        assert row.collateral_value_after_haircut == pytest.approx(
            attendu, rel=1e-3
        )


def test_crm_non_financee_expose_le_garant(rows):
    non_financees = _bucket(rows, "CRM non financee")
    if not non_financees:
        pytest.skip("Aucune CRM non financee dans ce jeu de donnees.")
    for row in non_financees:
        assert row.guarantor_name, f"{row.id} : garantie personnelle sans garant."
        # Une ponderation nulle est legitime (garant souverain de premiere
        # qualite) : c'est son absence de la reponse qui empechait de juger
        # l'interet de la substitution.
        assert row.guarantor_risk_weight >= 0
        assert 0 < row.crm_coverage_percent <= 1


def test_ponderation_retenue_est_la_moyenne_des_deux_poids(rows):
    non_financees = _bucket(rows, "CRM non financee")
    if not non_financees:
        pytest.skip("Aucune CRM non financee dans ce jeu de donnees.")
    for row in non_financees:
        couverture = row.crm_coverage_percent
        melange = (
            row.original_risk_weight * (1 - couverture)
            + row.guarantor_risk_weight * couverture
        )
        # La substitution ne joue que si elle allege : au-dela, la ligne reste
        # ponderee au poids du debiteur.
        assert row.final_risk_weight == pytest.approx(
            min(melange, row.original_risk_weight), rel=1e-3
        ), (
            f"{row.id} : la ponderation retenue doit rester la moyenne du "
            "poids du debiteur et de celui du garant, sans jamais depasser "
            "celle du debiteur seul."
        )


def test_rwa_avant_crm_egale_le_rwa_retenu_quand_il_n_y_a_pas_de_crm(rows):
    for row in _bucket(rows, "Aucune"):
        assert row.rwa_before_crm == pytest.approx(row.rwa, rel=1e-6), (
            f"{row.id} : sans technique d'attenuation, afficher un effet CRM "
            "non nul inventerait un gain."
        )


def test_une_surete_financee_ne_peut_pas_alourdir_le_rwa(rows):
    financees = _bucket(rows, "CRM financee")
    if not financees:
        pytest.skip("Aucune CRM financee dans ce jeu de donnees.")
    for row in financees:
        assert row.rwa_before_crm >= row.rwa - 1, (
            f"{row.id} : une surete deduite de l'exposition ne peut pas "
            "augmenter l'exigence."
        )


def test_rwa_avant_crm_reconstitue_l_exposition_avant_deduction(rows):
    financees = [
        row
        for row in _bucket(rows, "CRM financee")
        if row.crm_eligible and row.ead > 0
    ]
    if not financees:
        pytest.skip("Aucune CRM financee partiellement couverte.")
    for row in financees:
        # Tant que la surete n'epuise pas l'exposition, EAD avant CRM = EAD
        # retenue + surete deduite, ponderee au poids du debiteur (la CRM
        # financee ne change pas la ponderation).
        attendu = (
            row.ead + row.collateral_value_after_haircut
        ) * row.original_risk_weight
        assert row.rwa_before_crm == pytest.approx(attendu, rel=1e-3)


def test_aucune_garantie_n_alourdit_l_exigence(rows):
    """Principe bâlois : une technique d'attenuation ne peut pas couter.

    Reconnaitre une protection est une faculte : aucune banque ne declare une
    garantie qui la penalise. Une exposition garantie ne doit donc jamais
    supporter une exigence superieure a la meme exposition sans garantie.
    """

    for row in rows:
        assert row.rwa <= row.rwa_before_crm + 1, (
            f"{row.id} : la CRM alourdit l'exigence ({row.rwa} contre "
            f"{row.rwa_before_crm} sans garantie)."
        )


def test_une_garantie_sans_effet_reste_identifiable(rows):
    """La couverture affichee ne doit pas passer pour une reduction.

    Quand le garant est ponderé au moins aussi lourdement que le debiteur, la
    substitution n'est pas retenue : la ligne garde la ponderation du debiteur
    et son effet CRM est nul. C'est ce que l'ecran doit pouvoir signaler.
    """

    sans_effet = [
        row
        for row in _bucket(rows, "CRM non financee")
        if row.guarantor_risk_weight >= row.original_risk_weight
    ]
    if not sans_effet:
        pytest.skip("Aucune garantie sans effet dans ce jeu de donnees.")
    for row in sans_effet:
        assert row.final_risk_weight == pytest.approx(
            row.original_risk_weight, rel=1e-6
        )
        assert row.rwa == pytest.approx(row.rwa_before_crm, rel=1e-6)
        assert row.crm_coverage_percent > 0
