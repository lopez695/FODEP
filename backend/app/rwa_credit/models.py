"""Modèles de réponse de l'analyse RWA Crédit."""

from __future__ import annotations

from datetime import date

from pydantic import BaseModel, Field


class RwaCreditComparisonPeriod(BaseModel):
    """Option de période de comparaison proposée dans le bandeau de contexte."""

    key: str = Field(..., description="Identifiant technique de la période.")
    label: str = Field(..., description="Libellé affiché à l'utilisateur.")
    available: bool = Field(
        default=False,
        description="Vrai si un historique permet de calculer la variation.",
    )


class RwaCreditVariation(BaseModel):
    """Variation d'un indicateur par rapport à la période de comparaison."""

    amount: float = Field(..., description="Variation en montant (XOF).")
    percent: float = Field(..., description="Variation en pourcentage (ratio).")


class RwaCreditTranche(BaseModel):
    """Ventilation d'un agent par tranche de pondération réglementaire."""

    risk_weight: float = Field(..., description="Taux de pondération appliqué (ratio).")
    exposure: float = Field(..., description="EAD de la tranche (XOF).")
    rwa: float = Field(..., description="RWA de la tranche (XOF).")


class RwaCreditCounterparty(BaseModel):
    """Agrégat par contrepartie au sein d'un agent économique."""

    name: str = Field(..., description="Nom de la contrepartie.")
    gross_exposure: float = Field(
        default=0.0, description="Exposition brute agrégée de la contrepartie (XOF)."
    )
    exposure: float = Field(..., description="EAD agrégée de la contrepartie (XOF).")
    rwa: float = Field(..., description="RWA agrégé de la contrepartie (XOF).")
    capital_required: float = Field(
        ..., description="Capital requis = RWA × taux minimum (XOF)."
    )
    share: float = Field(
        ..., description="Part du RWA de l'agent économique (ratio 0–1)."
    )


class RwaCreditAgentRow(BaseModel):
    """Décomposition des RWA pour un agent économique (catégorie prudentielle)."""

    code: str = Field(..., description="Code de catégorie prudentielle (a–l).")
    label: str = Field(..., description="Libellé complet de l'agent économique.")
    gross_exposure: float = Field(..., description="Exposition brute (XOF).")
    ead: float = Field(..., description="Exposure at Default (XOF).")
    exposure_total: float = Field(
        ..., description="Exposition totale affichée dans le tableau (= EAD, XOF)."
    )
    rwa: float = Field(..., description="Actifs pondérés par les risques (XOF).")
    capital_required: float = Field(
        ..., description="Capital requis = RWA × taux minimum (XOF)."
    )
    contribution: float = Field(
        ..., description="Contribution au RWA total (ratio 0–1)."
    )
    average_weight: float = Field(
        ..., description="Pondération moyenne = RWA / EAD (ratio)."
    )
    expected_weight_min: float | None = Field(
        default=None, description="Borne basse de la plage de pondération attendue."
    )
    expected_weight_max: float | None = Field(
        default=None, description="Borne haute de la plage de pondération attendue."
    )
    weight_out_of_range: bool = Field(
        default=False,
        description="Vrai si la pondération moyenne sort de la plage attendue.",
    )
    rwa_variation: RwaCreditVariation | None = Field(
        default=None, description="Variation du RWA de l'agent vs période de comparaison."
    )
    tranches: list[RwaCreditTranche] = Field(
        default_factory=list,
        description="Ventilation par tranche de pondération (détail dépliable).",
    )
    counterparties: list[RwaCreditCounterparty] = Field(
        default_factory=list,
        description="Ventilation par contrepartie (dialogue Top 5 / Voir tout).",
    )


class RwaCreditTotals(BaseModel):
    """Totaux de portefeuille servant aux cartes de synthèse et au pied de tableau."""

    gross_exposure: float
    ead: float
    exposure_total: float
    rwa: float
    capital_required: float


class RwaCreditAnalysis(BaseModel):
    """Réponse complète alimentant l'onglet « Analyse RWA Crédit »."""

    reference_date: date | None = Field(
        default=None, description="Date d'arrêté des données (dernière date d'analyse)."
    )
    scope_label: str = Field(..., description="Périmètre affiché dans le bandeau.")
    minimum_capital_ratio: float = Field(
        ..., description="Taux minimum réglementaire appliqué (ratio 0–1)."
    )
    reconciliation_threshold: float = Field(
        ..., description="Seuil de tolérance du contrôle de réconciliation (ratio)."
    )
    comparison_periods: list[RwaCreditComparisonPeriod] = Field(default_factory=list)
    totals: RwaCreditTotals
    agents: list[RwaCreditAgentRow] = Field(default_factory=list)

    # --- Cartes de synthèse (Phase 2) ---
    density_rwa: float = Field(
        default=0.0, description="Densité RWA = RWA / EAD (pondération moyenne, ratio)."
    )
    density_trend: list[float] = Field(
        default_factory=list,
        description="Densité RWA des 6 dernières périodes (vide si pas d'historique).",
    )
    own_funds: float | None = Field(
        default=None, description="Fonds propres effectifs (XOF), si paramétrés."
    )
    own_funds_available: bool = Field(
        default=False, description="Vrai si les fonds propres sont renseignés."
    )
    capital_margin: float | None = Field(
        default=None,
        description="Marge de capital = fonds propres effectifs − capital requis (XOF).",
    )
    solvency_ratio: float | None = Field(
        default=None,
        description="Ratio de solvabilité = fonds propres effectifs / RWA total (ratio).",
    )
    rwa_total: float | None = Field(
        default=None,
        description="RWA total (crédit + marché + opérationnel) servant à la solvabilité.",
    )
    exposure_variation: RwaCreditVariation | None = Field(
        default=None, description="Variation de l'EAD vs période de comparaison."
    )
    rwa_variation: RwaCreditVariation | None = Field(
        default=None, description="Variation du RWA Crédit vs période de comparaison."
    )
