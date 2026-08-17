"""Routes FastAPI du module Risque Opérationnel."""

from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import Response

from .models import (
    AibCalculResult,
    AsCalculResult,
    BetaLigneUpdate,
    BetaLigneView,
    ControleCreate,
    ControleUpdate,
    ControleView,
    DashboardData,
    DecisionPilotageResult,
    HistoriqueView,
    IncidentBulkImportRequest,
    IncidentCreate,
    IncidentImportResult,
    IncidentUpdate,
    IncidentView,
    KriModuleData,
    KriValeurCreate,
    KriValeurView,
    OpRiskCalculResult,
    OpRiskInput,
    OpRiskInputUpdate,
    OpRiskParametres,
    OpRiskParametresUpdate,
    ParametresAib,
    ParametresAibUpdate,
    ParametresAs,
    ParametresAsUpdate,
    ParametresSeuils,
    ParametresSeuilsUpdate,
    PlanCreate,
    PlanUpdate,
    PlanView,
    PnbAnnuelCreate,
    PnbAnnuelView,
    PnbParLigneCreate,
    PnbParLigneView,
    RisqueCreate,
    RisqueUpdate,
    RisqueView,
    SyntheseResult,
)
from . import services

router = APIRouter(prefix="/risque-operationnel", tags=["Risque Opérationnel"])


# ─── Dashboard ────────────────────────────────────────────────────────────────

@router.get("/dashboard", response_model=DashboardData)
def get_dashboard() -> DashboardData:
    return services.get_dashboard()


# ─── Incidents ────────────────────────────────────────────────────────────────

@router.get("/incidents", response_model=list[IncidentView])
def list_incidents(
    statut: str | None = Query(default=None),
    ligne_metier: str | None = Query(default=None),
) -> list[IncidentView]:
    return services.list_incidents(statut=statut, ligne_metier=ligne_metier)


@router.post("/incidents", response_model=IncidentView, status_code=201)
def create_incident(data: IncidentCreate) -> IncidentView:
    return services.create_incident(data)


@router.put("/incidents/{id_}", response_model=IncidentView)
def update_incident(id_: str, data: IncidentUpdate) -> IncidentView:
    try:
        return services.update_incident(id_, data)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.delete("/incidents/{id_}", status_code=204)
def delete_incident(id_: str) -> None:
    services.delete_incident(id_)


@router.get("/incidents/import/template")
def download_import_template() -> Response:
    """Télécharge le modèle Excel d'import des pertes opérationnelles."""
    template_bytes = services.build_ro_import_template()
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=modele_import_pertes_op.xlsx"},
    )


@router.post("/incidents/import", response_model=IncidentImportResult)
def bulk_import_incidents(data: IncidentBulkImportRequest) -> IncidentImportResult:
    return services.bulk_import_incidents(data)


# ─── KRI ──────────────────────────────────────────────────────────────────────

@router.get("/kri", response_model=KriModuleData)
def get_kri() -> KriModuleData:
    return services.get_kri_module()


@router.post("/kri/valeurs", response_model=KriValeurView, status_code=201)
def add_kri_valeur(data: KriValeurCreate) -> KriValeurView:
    return services.add_kri_valeur(data)


# ─── Cartographie des risques ─────────────────────────────────────────────────

@router.get("/risques", response_model=list[RisqueView])
def list_risques() -> list[RisqueView]:
    return services.list_risques()


@router.post("/risques", response_model=RisqueView, status_code=201)
def create_risque(data: RisqueCreate) -> RisqueView:
    return services.create_risque(data)


@router.put("/risques/{id_}", response_model=RisqueView)
def update_risque(id_: str, data: RisqueUpdate) -> RisqueView:
    return services.update_risque(id_, data)


@router.delete("/risques/{id_}", status_code=204)
def delete_risque(id_: str) -> None:
    services.delete_risque(id_)


# ─── Contrôles internes ───────────────────────────────────────────────────────

@router.get("/controles", response_model=list[ControleView])
def list_controles() -> list[ControleView]:
    return services.list_controles()


@router.post("/controles", response_model=ControleView, status_code=201)
def create_controle(data: ControleCreate) -> ControleView:
    return services.create_controle(data)


@router.put("/controles/{id_}", response_model=ControleView)
def update_controle(id_: str, data: ControleUpdate) -> ControleView:
    return services.update_controle(id_, data)


@router.delete("/controles/{id_}", status_code=204)
def delete_controle(id_: str) -> None:
    services.delete_controle(id_)


# ─── Plans d'actions ──────────────────────────────────────────────────────────

@router.get("/plans", response_model=list[PlanView])
def list_plans() -> list[PlanView]:
    return services.list_plans()


@router.post("/plans", response_model=PlanView, status_code=201)
def create_plan(data: PlanCreate) -> PlanView:
    return services.create_plan(data)


@router.put("/plans/{id_}", response_model=PlanView)
def update_plan(id_: str, data: PlanUpdate) -> PlanView:
    return services.update_plan(id_, data)


@router.delete("/plans/{id_}", status_code=204)
def delete_plan(id_: str) -> None:
    services.delete_plan(id_)


# ─── Historique ───────────────────────────────────────────────────────────────

@router.get("/historique", response_model=list[HistoriqueView])
def list_historique(limit: int = Query(default=200, le=1000)) -> list[HistoriqueView]:
    return services.list_historique(limit=limit)


# ─── BIC — Approche Standard CRR3 ────────────────────────────────────────────

@router.get("/bic/inputs", response_model=list[OpRiskInput])
def list_bic_inputs() -> list[OpRiskInput]:
    """Toutes les années ayant des postes BIC/CCR3 enregistrés (saisie ou
    import Excel), sans se limiter à la fenêtre N-2/N-1/N par défaut."""
    return services.list_op_risk_inputs()


@router.get("/bic/inputs/{annee}", response_model=OpRiskInput)
def get_bic_input(annee: int) -> OpRiskInput:
    return services.get_op_risk_input(annee)


@router.put("/bic/inputs/{annee}", response_model=OpRiskInput)
def upsert_bic_input(annee: int, data: OpRiskInputUpdate) -> OpRiskInput:
    return services.upsert_op_risk_input(annee, data)


@router.get("/bic/parametres", response_model=OpRiskParametres)
def get_bic_parametres() -> OpRiskParametres:
    return services.get_op_risk_parametres()


@router.put("/bic/parametres", response_model=OpRiskParametres)
def update_bic_parametres(data: OpRiskParametresUpdate) -> OpRiskParametres:
    return services.update_op_risk_parametres(data)


@router.get("/bic/calcul", response_model=OpRiskCalculResult)
def calcul_bic(annee_n: int | None = Query(default=None)) -> OpRiskCalculResult:
    return services.calcul_bic(annee_n=annee_n)


@router.get("/bic/import/template")
def download_bic_import_template() -> Response:
    """Télécharge le modèle Excel d'import des postes BIC/CCR3."""
    template_bytes = services.build_bic_import_template()
    return Response(
        content=template_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=modele_import_bic_ccr3.xlsx"},
    )


# ─── BLOC A1 — AIB (Approche Indicateur de Base) ─────────────────────────────

@router.get("/aib/pnb", response_model=list[PnbAnnuelView])
def list_pnb_annuel() -> list[PnbAnnuelView]:
    return services.list_pnb_annuel()


@router.put("/aib/pnb/{annee}", response_model=PnbAnnuelView)
def upsert_pnb_annuel(annee: int, data: PnbAnnuelCreate) -> PnbAnnuelView:
    try:
        return services.upsert_pnb_annuel(annee, data)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/aib/pnb/{annee}", status_code=204)
def delete_pnb_annuel(annee: int) -> None:
    services.delete_pnb_annuel(annee)


@router.get("/aib/parametres", response_model=ParametresAib)
def get_aib_parametres() -> ParametresAib:
    return services.get_aib_parametres()


@router.put("/aib/parametres", response_model=ParametresAib)
def update_aib_parametres(data: ParametresAibUpdate) -> ParametresAib:
    return services.update_aib_parametres(data)


@router.get("/aib/calcul", response_model=AibCalculResult)
def calcul_aib() -> AibCalculResult:
    return services.calcul_aib()


@router.get("/aib/decision", response_model=DecisionPilotageResult)
def get_decision_aib() -> DecisionPilotageResult:
    return services.get_decision_aib()


# ─── BLOC A2 — AS (Approche Standard) ────────────────────────────────────────

@router.get("/as/beta-lignes", response_model=list[BetaLigneView])
def list_beta_lignes() -> list[BetaLigneView]:
    return services.list_beta_lignes()


@router.put("/as/beta-lignes/{ligne_metier:path}", response_model=BetaLigneView)
def update_beta_ligne(ligne_metier: str, data: BetaLigneUpdate) -> BetaLigneView:
    return services.update_beta_ligne(ligne_metier, data)


@router.get("/as/pnb-lignes/{annee}", response_model=list[PnbParLigneView])
def get_pnb_lignes(annee: int) -> list[PnbParLigneView]:
    return services.get_pnb_lignes(annee)


@router.put("/as/pnb-lignes/{annee}/{ligne_metier:path}", response_model=PnbParLigneView)
def upsert_pnb_ligne(annee: int, ligne_metier: str, data: PnbParLigneCreate) -> PnbParLigneView:
    return services.upsert_pnb_ligne(annee, ligne_metier, data)


@router.get("/as/parametres", response_model=ParametresAs)
def get_as_parametres() -> ParametresAs:
    return services.get_as_parametres()


@router.put("/as/parametres", response_model=ParametresAs)
def update_as_parametres(data: ParametresAsUpdate) -> ParametresAs:
    return services.update_as_parametres(data)


@router.get("/as/calcul", response_model=AsCalculResult)
def calcul_as() -> AsCalculResult:
    return services.calcul_as()


@router.get("/as/decision", response_model=DecisionPilotageResult)
def get_decision_as() -> DecisionPilotageResult:
    return services.get_decision_as()


# ─── Seuils de reporting Pilier 2 ────────────────────────────────────────────

@router.get("/pertes/seuils", response_model=ParametresSeuils)
def get_pertes_seuils() -> ParametresSeuils:
    return services.get_pertes_seuils()


@router.put("/pertes/seuils", response_model=ParametresSeuils)
def update_pertes_seuils(data: ParametresSeuilsUpdate) -> ParametresSeuils:
    return services.update_pertes_seuils(data)


# ─── Synthèse comparative AIB / AS / BIC ─────────────────────────────────────

@router.get("/synthese", response_model=SyntheseResult)
def get_synthese() -> SyntheseResult:
    return services.get_synthese()


# ─── Décision de pilotage — Analyse et reporting (dispositif UEMOA) ──────────

@router.get("/pilotage/decision", response_model=DecisionPilotageResult)
def get_decision_pilotage() -> DecisionPilotageResult:
    return services.get_decision_pilotage()
