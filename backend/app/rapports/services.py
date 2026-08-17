"""Services metier du module rapports."""

from __future__ import annotations

from datetime import date

from app.expositions.services import list_expositions
from app.hors_bilan.services import list_commitments
from app.rapports.fodep.saisies import (
    catalogue_adpe,
    enregistrer_saisies,
    lire_saisies,
)
from app.rapports.models import (
    CaseFodep,
    EtatASaisir,
    ReportLine,
    ReportRequest,
    ReportView,
    SaisiesFodep,
)
from database.repositories.report_repository import report_repository

def _next_report_id() -> str:
    """Genere le prochain identifiant de rapport."""

    return report_repository.next_report_id()


def list_reports() -> list[ReportView]:
    """Retourne la liste des rapports deja generes."""

    reports: list[ReportView] = []
    for item in report_repository.list_reports():
        reports.append(
            ReportView(
                id=item["id"],
                created_at=item["created_at"],
                period=item["period"],
                report_type=item["report_type"],
                currency=item["currency"],
                exposure_scope=item["exposure_scope"],
                include_category_chart=item["include_category_chart"],
                include_rating_chart=item["include_rating_chart"],
                exports=item["exports"],
                lines=[ReportLine.model_validate(line) for line in item.get("lines", [])],
            )
        )
    return reports


def generate_report(payload: ReportRequest) -> ReportView:
    """Genere un rapport de synthese ou detaille."""

    report_id = _next_report_id()
    lines: list[ReportLine] = []

    for exposure in list_expositions():
        lines.append(
            ReportLine(
                source="Exposition",
                item_id=exposure.id,
                counterparty=exposure.counterparty.name,
                amount=exposure.gross_amount,
                ead=exposure.ead,
                rwa=exposure.rwa,
                capital=exposure.capital,
            )
        )

    for commitment in list_commitments():
        lines.append(
            ReportLine(
                source="Hors bilan",
                item_id=commitment.id,
                counterparty=commitment.counterparty_name,
                amount=commitment.nominal_amount,
                ead=commitment.ead,
                rwa=commitment.rwa,
                capital=commitment.capital,
            )
        )

    report_view = ReportView(
        id=report_id,
        created_at=date.today(),
        period=payload.period,
        report_type=payload.report_type,
        currency=payload.currency,
        exposure_scope=payload.exposure_scope,
        include_category_chart=payload.include_category_chart,
        include_rating_chart=payload.include_rating_chart,
        exports={
            "pdf": f"/exports/{report_id}.pdf",
            "excel": f"/exports/{report_id}.xlsx",
        },
        lines=lines if payload.report_type == "Detaille" else lines[:5],
    )
    report_repository.save_report(
        {
            "id": report_view.id,
            "created_at": report_view.created_at,
            "period": report_view.period,
            "report_type": report_view.report_type,
            "currency": report_view.currency,
            "exposure_scope": report_view.exposure_scope,
            "include_category_chart": report_view.include_category_chart,
            "include_rating_chart": report_view.include_rating_chart,
            "exports": report_view.exports,
            "lines": [line.model_dump() for line in report_view.lines],
        }
    )
    return report_view


# ─── Saisies manuelles du FODEP ─────────────────────────────────────────────


def lire_cases_a_saisir() -> SaisiesFodep:
    """Champs de l'attestation, et valeurs deja portees par le declarant.

    L'attestation est la seule feuille que l'application ne produira jamais :
    l'identite de l'etablissement et celle des signataires ne se deduisent
    d'aucune donnee du portefeuille. Le reste du formulaire vient de l'outil,
    ou est declare a zero.
    """

    valeurs = lire_saisies()
    cases = []
    for case in catalogue_adpe():
        saisie = valeurs.get((case.etat, case.cellule))
        cases.append(
            CaseFodep(
                etat=case.etat,
                cellule=case.cellule,
                ligne=case.ligne,
                code=case.code,
                libelle=case.libelle,
                colonne=case.colonne,
                type_saisie=case.type_saisie,
                valeur=saisie.valeur if saisie else None,
                texte=saisie.texte if saisie else None,
                commentaire=saisie.commentaire if saisie else None,
            )
        )

    renseignees = sum(
        1 for case in cases if case.valeur is not None or bool(case.texte)
    )
    attestation = EtatASaisir(
        etat="ADPE",
        intitule="Attestation de déclaration prudentielle : identité de "
        "l'établissement et signataires",
        cases=cases,
        renseignees=renseignees,
        obligatoire=True,
    )
    return SaisiesFodep(
        etats=[attestation],
        total_cases=len(cases),
        total_renseignees=renseignees,
    )


def enregistrer_saisies_fodep(saisies: list[CaseFodep]) -> int:
    """Enregistre les saisies transmises par l'ecran."""

    return enregistrer_saisies([saisie.model_dump() for saisie in saisies])
