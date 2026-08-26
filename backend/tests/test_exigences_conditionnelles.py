"""Tests de validation des champs obligatoires et des exigences conditionnelles à l'import.

Une colonne « optionnelle » ne l'est que parce qu'elle ne concerne pas toutes
les catégories. Laissée vide là où elle s'applique, elle ne doit pas fausser
le calcul en silence : l'import doit être refusé en bloc avec un rapport clair.
"""

from __future__ import annotations

import pytest

from app.validators.excel_import_validator import (
    ExcelImportValidationError,
    controler_exigences_conditionnelles,
)
from database.services.excel_import_service import ExcelImportService


def _ligne_base(**modifications) -> dict:
    valeurs = {
        "Date d'analyse": "2026-06-30",
        "ID_Exposition": "EXP-TEST-001",
        "Contrepartie": "ENTREPRISE TEST SA",
        "N_Centrale_risques": "CR-CI-1234",
        "Secteur_activite": "Industrie manufacturiere",
        "Groupe_clients_lies": "Néant",
        "N_Centrale_risques_groupe": "Néant",
        "Categorie_lien": "Néant",
        "Partie_liee": "Néant",
        "Notation_externe_contrepartie": "BBB",
        "Pays_contrepartie": "Côte d'Ivoire",
        "Notation_externe_pays": "AAA",
        "Catégorie d'exposition": "Entreprises",
        "Montant_exposition_but_au_bilan": 100000000,
        "Devise": "XOF",
        "Type_CRM": "Aucune",
        "Date d'octroi": "2024-01-01",
        "Date d'échéance": "2027-01-01",
        "PRÊT TOTAL": 100000000,
        "Montant d'exposition au HB": 0,
        "Niveau de risque HB": "Risque faible",
        "Statut": "Active",
        "Provisions": 0,
        "Jours_impayes": 0,
        "Regime_prudentiel_specifique": "Standard (aucun traitement particulier)",
    }
    valeurs.update(modifications)
    return valeurs


def test_ligne_complete_conforme_aucun_manque():
    ligne = _ligne_base()
    manques = controler_exigences_conditionnelles([(2, ligne)])
    assert not manques


def test_regime_prudentiel_specifique_vide_est_accepte_par_defaut():
    ligne = _ligne_base(Regime_prudentiel_specifique="")
    manques = controler_exigences_conditionnelles([(2, ligne)])
    assert not manques


def test_immobilier_residentiel_sans_pret_total_est_signale():
    ligne = _ligne_base(
        **{
            "Catégorie d'exposition": "Prêts garantis par l'immo R",
            "PRÊT TOTAL": None,
        }
    )
    manques = controler_exigences_conditionnelles([(3, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "PRÊT TOTAL" in colonnes_manquantes


def test_immobilier_commercial_sans_pret_total_est_signale():
    ligne = _ligne_base(
        **{
            "Catégorie d'exposition": "Prêts garantis par l'immo C",
            "PRÊT TOTAL": "",
        }
    )
    manques = controler_exigences_conditionnelles([(4, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "PRÊT TOTAL" in colonnes_manquantes


def test_autres_actifs_sans_type_autre_actif_est_signale():
    ligne = _ligne_base(
        **{
            "Catégorie d'exposition": "Autres actifs",
            "Type_autre_actif": None,
        }
    )
    manques = controler_exigences_conditionnelles([(5, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "Type_autre_actif" in colonnes_manquantes


def test_creances_en_souffrance_sans_jours_ni_ponderation_est_signale():
    ligne = _ligne_base(
        **{
            "Catégorie d'exposition": "Créances en souffrance",
            "Provisions": None,
            "Jours_impayes": "",
            "Ponderation_initiale_avant_defaut": None,
        }
    )
    manques = controler_exigences_conditionnelles([(6, ligne)])
    colonnes_manquantes = {m["colonne"] for m in manques}
    assert "Jours_impayes" in colonnes_manquantes
    assert "Ponderation_initiale_avant_defaut" in colonnes_manquantes


def test_hors_bilan_montant_sans_niveau_est_signale():
    ligne = _ligne_base(
        **{
            "Montant d'exposition au HB": 50000000,
            "Niveau de risque HB": "",
        }
    )
    manques = controler_exigences_conditionnelles([(7, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "Niveau de risque HB" in colonnes_manquantes


def test_hors_bilan_niveau_sans_montant_est_signale():
    ligne = _ligne_base(
        **{
            "Montant d'exposition au HB": None,
            "Niveau de risque HB": "Risque moyen",
        }
    )
    manques = controler_exigences_conditionnelles([(8, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "Montant d'exposition au HB" in colonnes_manquantes


def test_identification_centrale_risques_manquante_ou_neant_est_signalee():
    ligne = _ligne_base(N_Centrale_risques="Néant")
    manques = controler_exigences_conditionnelles([(9, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "N_Centrale_risques" in colonnes_manquantes


def test_identification_secteur_activite_manquant_ou_neant_est_signale():
    ligne = _ligne_base(Secteur_activite="sans objet")
    manques = controler_exigences_conditionnelles([(10, ligne)])
    colonnes_manquantes = [m["colonne"] for m in manques]
    assert "Secteur_activite" in colonnes_manquantes


def test_groupe_clients_lies_et_partie_liee_vides_sont_acceptes():
    ligne = _ligne_base(
        Groupe_clients_lies="",
        N_Centrale_risques_groupe="",
        Categorie_lien="",
        Partie_liee="",
        Regime_prudentiel_specifique="",
    )
    manques = controler_exigences_conditionnelles([(11, ligne)])
    assert not manques


def test_import_rejete_en_bloc_si_manque():
    service = ExcelImportService.__new__(ExcelImportService)
    lignes = [
        (
            2,
            _ligne_base(
                **{
                    "Catégorie d'exposition": "Prêts garantis par l'immo R",
                    "PRÊT TOTAL": None,
                }
            ),
        )
    ]
    bundle = type("B", (), {"template_rows": lignes})()
    with pytest.raises(ExcelImportValidationError) as exc:
        service._ensure_exigences_conditionnelles(bundle)
    assert "case(s) exigée(s) par leur contexte" in str(exc.value)
