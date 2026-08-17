"""Routes API du module expositions."""

from __future__ import annotations

from zipfile import BadZipFile
import json

from fastapi import APIRouter, File, Form, HTTPException, Query, Response, UploadFile, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from app.validators.excel_import_validator import ExcelImportValidationError
from app.expositions import suivi_service
from app.expositions.models import ExposureCreate, ExposureSummary, ExposureView
from app.expositions.services import (
    build_expositions_excel_export,
    build_excel_import_template,
    create_exposition,
    delete_exposition,
    delete_expositions,
    export_expositions_to_csv,
    export_expositions_to_json,
    export_to_excel,
    get_excel_import_spec,
    get_next_exposition_id,
    get_exposition_summary,
    import_csv_data,
    inspect_uploaded_workbook,
    import_uploaded_workbook,
    list_expositions,
    preview_exposition,
    update_exposition,
)

router = APIRouter(prefix="/expositions", tags=["Expositions"])


class CsvImportRequest(BaseModel):
    """Modele de payload pour l'import CSV/TSV."""

    content: str


class ExposureDeleteRequest(BaseModel):
    """Modele de payload pour la suppression groupée d'expositions."""

    ids: list[str]
    reindex_ids: bool = False


class VersementRequest(BaseModel):
    """Marquage mensuel d'un versement reçu ou d'un impayé."""

    periode: str
    statut: str
    montant_verse: float | None = None
    commentaire: str | None = None


class DeclassementRequest(BaseModel):
    """Déclassement manuel en créance douteuse (motif obligatoire)."""

    motif: str


def _suivi_error_to_http(exc: Exception) -> HTTPException:
    if isinstance(exc, suivi_service.ExpositionIntrouvableError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
    if isinstance(exc, suivi_service.LeveeDeclassementRefuseeError):
        return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("", response_model=list[ExposureView])
def get_expositions(
    search: str | None = Query(default=None),
    category: str | None = Query(default=None),
) -> list[ExposureView]:
    """Retourne les expositions avec filtres simples."""

    return list_expositions(search=search, category=category)


@router.post("", response_model=ExposureView, status_code=status.HTTP_201_CREATED)
def post_exposition(payload: ExposureCreate) -> ExposureView:
    """Cree une exposition au bilan."""

    return create_exposition(payload)


@router.post("/preview", response_model=ExposureView)
def post_exposition_preview(payload: ExposureCreate) -> ExposureView:
    """Calcule une exposition sans l'enregistrer."""

    return preview_exposition(payload)


@router.get("/next-id")
def get_next_exposure_id() -> dict[str, str]:
    """Retourne le prochain identifiant CP disponible pour la saisie."""

    return {"id": get_next_exposition_id()}


@router.get("/summary", response_model=ExposureSummary)
def get_expositions_summary() -> ExposureSummary:
    """Retourne les agregats du portefeuille d'expositions."""

    return get_exposition_summary()


@router.post("/delete")
def remove_expositions(
    payload: ExposureDeleteRequest,
) -> dict[str, int | list[str] | bool | dict[str, str]]:
    """Supprime plusieurs expositions par identifiant."""

    return delete_expositions(
        payload.ids,
        reindex_ids=payload.reindex_ids,
    )


@router.post("/import/csv")
def import_from_csv(request: CsvImportRequest) -> dict[str, int | str | list[str]]:
    """Importe des donnees CSV/TSV dans la source Excel active."""

    return import_csv_data(request.content)


@router.post("/import/upload")
async def import_from_uploaded_excel(
    file: UploadFile = File(...),
    mode: str = Form("merge"),
) -> dict[str, object]:
    """Importe les donnees d'un fichier Excel uploadé."""

    workbook_bytes = await file.read()
    if not workbook_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Le fichier Excel est vide.")

    try:
        return import_uploaded_workbook(workbook_bytes, file.filename, mode=mode)
    except BadZipFile as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le fichier doit etre un classeur Excel .xlsx valide.",
        ) from exc
    except ExcelImportValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.payload) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/{exposure_id}/suivi")
def get_suivi_exposition(exposure_id: str) -> dict[str, object]:
    """Retourne le suivi mensuel des versements et le statut prudentiel."""

    try:
        return suivi_service.get_suivi(exposure_id)
    except suivi_service.ExpositionIntrouvableError as exc:
        raise _suivi_error_to_http(exc) from exc


@router.post("/{exposure_id}/suivi/versements")
def post_versement(exposure_id: str, payload: VersementRequest) -> dict[str, object]:
    """Enregistre le versement (ou l'impayé) d'un mois et recalcule la ligne."""

    try:
        return suivi_service.record_versement(
            exposure_id,
            periode=payload.periode,
            statut=payload.statut,
            montant_verse=payload.montant_verse,
            commentaire=payload.commentaire,
        )
    except (
        suivi_service.ExpositionIntrouvableError,
        suivi_service.SuiviValidationError,
    ) as exc:
        raise _suivi_error_to_http(exc) from exc


@router.post("/{exposure_id}/declassement")
def post_declassement(
    exposure_id: str, payload: DeclassementRequest
) -> dict[str, object]:
    """Déclasse manuellement une exposition en créance douteuse."""

    try:
        return suivi_service.declasser_exposition(exposure_id, motif=payload.motif)
    except (
        suivi_service.ExpositionIntrouvableError,
        suivi_service.SuiviValidationError,
    ) as exc:
        raise _suivi_error_to_http(exc) from exc


@router.post("/{exposure_id}/declassement/levee")
def post_levee_declassement(
    exposure_id: str, payload: DeclassementRequest
) -> dict[str, object]:
    """Lève un déclassement manuel après apurement des arriérés."""

    try:
        return suivi_service.lever_declassement(exposure_id, motif=payload.motif)
    except (
        suivi_service.ExpositionIntrouvableError,
        suivi_service.SuiviValidationError,
        suivi_service.LeveeDeclassementRefuseeError,
    ) as exc:
        raise _suivi_error_to_http(exc) from exc


@router.put("/{exposure_id}", response_model=ExposureView)
def put_exposition(exposure_id: str, payload: ExposureCreate) -> ExposureView:
    """Met a jour une exposition existante."""

    return update_exposition(exposure_id, payload)


@router.delete("/{exposure_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_exposition(exposure_id: str) -> Response:
    """Supprime une exposition existante."""

    deleted = delete_exposition(exposure_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Exposition introuvable.",
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/import/spec")
def get_import_excel_spec() -> dict[str, object]:
    """Retourne le format d'import attendu pour les fichiers Excel."""

    return get_excel_import_spec()


@router.get("/import/template")
def download_import_excel_template() -> StreamingResponse:
    """Télécharge un modèle Excel d'import."""

    template_bytes = build_excel_import_template()
    return StreamingResponse(
        iter([template_bytes]),
        media_type=(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ),
        headers={
            "Content-Disposition": "attachment; filename=modele_import_rwa.xlsx",
        },
    )


@router.post("/import/upload/inspect")
async def inspect_uploaded_excel(file: UploadFile = File(...)) -> dict[str, object]:
    """Inspecte un fichier Excel uploadé sans importer en base."""

    workbook_bytes = await file.read()
    if not workbook_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Le fichier Excel est vide.")

    try:
        return inspect_uploaded_workbook(workbook_bytes, file.filename)
    except BadZipFile as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le fichier doit etre un classeur Excel .xlsx valide.",
        ) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/export/csv")
def export_to_csv() -> StreamingResponse:
    """Exporte les expositions en fichier CSV."""

    return StreamingResponse(
        export_expositions_to_csv(),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=expositions.csv"},
    )


@router.get("/export/json")
def export_to_json() -> StreamingResponse:
    """Exporte les expositions en fichier JSON."""

    payload = export_expositions_to_json()
    json_bytes = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    return StreamingResponse(
        iter([json_bytes]),
        media_type="application/json",
        headers={"Content-Disposition": "attachment; filename=expositions.json"},
    )


@router.post("/export/excel")
def export_to_excel_file() -> dict[str, str | int]:
    """Genere un fichier Excel d'export pour les expositions."""

    return export_to_excel()


@router.get("/export/excel/download")
def download_excel_export() -> StreamingResponse:
    """Télécharge l'export Excel complet des expositions."""

    workbook_bytes = build_expositions_excel_export()
    return StreamingResponse(
        iter([workbook_bytes]),
        media_type=(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ),
        headers={
            "Content-Disposition": "attachment; filename=export_expositions_rwa.xlsx",
        },
    )
