"""Routes API du module rapports."""

from datetime import date
import json
import logging

from fastapi import APIRouter, File, HTTPException, Query, UploadFile, status
from fastapi.responses import StreamingResponse

from app.rapports.fodep import construire_fodep, nom_fichier_fodep
from app.rapports.fodep.analyse import AnalyseDeclaration, analyser_declaration
from app.rapports.fodep.contenu import ContenuFodep, contenu_fodep
from app.rapports.models import (
    ReportRequest,
    ReportView,
    SaisiesFodep,
    SaisiesFodepEnregistrees,
)
from app.rapports.services import (
    enregistrer_saisies_fodep,
    generate_report,
    lire_cases_a_saisir,
    list_reports,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/rapports", tags=["Rapports"])

TYPE_MIME_CLASSEUR = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)


@router.get("", response_model=list[ReportView])
def get_reports() -> list[ReportView]:
    """Retourne les rapports disponibles."""

    return list_reports()


@router.post("", response_model=ReportView, status_code=status.HTTP_201_CREATED)
def post_report(payload: ReportRequest) -> ReportView:
    """Genere un nouveau rapport."""

    return generate_report(payload)


@router.get("/fodep/saisies", response_model=SaisiesFodep)
def get_saisies_fodep() -> SaisiesFodep:
    """Cases que le declarant doit renseigner lui-meme, et ce qu'il y a porte.

    Le catalogue est lu dans le formulaire : ce sont les cases que la BCEAO a
    laissees deverrouillees sur les etats dont l'application n'a pas la source.
    """

    return lire_cases_a_saisir()


@router.put("/fodep/saisies", response_model=SaisiesFodepEnregistrees)
def put_saisies_fodep(payload: SaisiesFodepEnregistrees) -> SaisiesFodepEnregistrees:
    """Enregistre des saisies. Une valeur nulle efface la case."""

    enregistrees = enregistrer_saisies_fodep(payload.saisies, payload.date_arrete)
    return SaisiesFodepEnregistrees(
        saisies=payload.saisies,
        enregistrees=enregistrees,
        date_arrete=payload.date_arrete,
    )


@router.post("/fodep/analyse", response_model=AnalyseDeclaration)
async def post_analyse_fodep(
    file: UploadFile = File(...),
) -> AnalyseDeclaration:
    """Analyse une déclaration FODEP au regard du dispositif prudentiel UMOA.

    Le PDF déposé n'a pas à venir de cet outil : une déclaration d'un exercice
    précédent ou d'une autre entité s'analyse aussi bien. Seules les onze normes
    de l'EP01 sont confrontées à leurs seuils — c'est l'état de conformité du
    formulaire.
    """

    octets = await file.read()
    if not octets:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "FODEP_ANALYSE_FICHIER_VIDE",
                "message": "Le fichier déposé est vide.",
            },
        )
    try:
        return analyser_declaration(octets, file.filename or "declaration.pdf")
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "FODEP_ANALYSE_PDF_ILLISIBLE", "message": str(exc)},
        ) from exc


@router.get("/fodep/contenu", response_model=ContenuFodep)
def get_contenu_fodep(
    date_arrete: date | None = Query(
        default=None,
        description=(
            "Date d'arrêté de la déclaration. Par défaut, la date d'analyse la "
            "plus récente du portefeuille."
        ),
    ),
) -> ContenuFodep:
    """Contenu du FODEP renseigné, état par état, pour en faire un PDF.

    Le classeur reste la pièce déclarative ; cette route en donne la lecture.
    L'extraction se fait ici parce que la bibliothèque Excel du poste de travail
    échoue à décoder ce formulaire, qu'openpyxl vient pourtant d'écrire.
    """

    try:
        return contenu_fodep(date_arrete)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "FODEP_MODELE_ABSENT", "message": str(exc)},
        ) from exc


@router.get("/fodep/export")
def telecharger_fodep(
    date_arrete: date | None = Query(
        default=None,
        description=(
            "Date d'arrêté de la déclaration. Par défaut, la date d'analyse la "
            "plus récente du portefeuille."
        ),
    ),
) -> StreamingResponse:
    """Télécharge le Formulaire de Déclaration Prudentielle (FODEP) renseigné."""

    try:
        resultat = construire_fodep(date_arrete)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "FODEP_MODELE_ABSENT",
                "message": str(exc),
            },
        ) from exc

    for anomalie in resultat.anomalies:
        logger.warning("Export FODEP : %s", anomalie)

    entetes = {
        "Content-Disposition": (
            f"attachment; filename={nom_fichier_fodep(resultat.date_arrete)}"
        ),
        # Les réserves de lecture voyagent avec le fichier : l'interface les
        # affiche pour que personne ne transmette la déclaration en ignorant
        # les postes que l'application ne sait pas encore alimenter. Les
        # accents sont échappés en \\uXXXX : un en-tête HTTP ne transporte que
        # de l'ASCII, et un « é » brut y suffirait à faire échouer l'envoi.
        "X-Fodep-Anomalies": json.dumps(resultat.anomalies),
    }
    return StreamingResponse(
        iter([resultat.contenu]),
        media_type=TYPE_MIME_CLASSEUR,
        headers=entetes,
    )
