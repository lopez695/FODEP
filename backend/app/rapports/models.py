"""Modeles du module rapports."""

from datetime import date

from pydantic import BaseModel, Field


class ReportRequest(BaseModel):
    """Represente les filtres utilises pour generer un rapport."""

    period: str = Field(..., description="Periode de reporting.")
    report_type: str = Field(..., description="Type de rapport attendu.")
    currency: str = Field(default="EUR", description="Monnaie du rapport.")
    exposure_scope: str = Field(default="Toutes", description="Portee des expositions.")
    include_category_chart: bool = Field(default=True, description="Inclut la repartition par categorie.")
    include_rating_chart: bool = Field(default=True, description="Inclut la repartition par notation.")


class ReportLine(BaseModel):
    """Represente une ligne de rapport detaille."""

    source: str
    item_id: str
    counterparty: str
    amount: float
    ead: float
    rwa: float
    capital: float


class ReportView(BaseModel):
    """Represente un rapport genere et ses exports."""

    id: str
    created_at: date
    period: str
    report_type: str
    currency: str
    exposure_scope: str
    include_category_chart: bool
    include_rating_chart: bool
    exports: dict[str, str]
    lines: list[ReportLine] = []


class CaseFodep(BaseModel):
    """Une case du FODEP que le declarant renseigne lui-meme.

    L'adresse (etat, cellule) est la cle : elle ne bouge pas avec l'ordre des
    lignes. Le code DISPRU, l'intitule et l'en-tete de colonne accompagnent la
    case pour que l'ecran la designe comme le formulaire la designe.
    """

    etat: str
    cellule: str
    ligne: int
    code: str
    libelle: str
    colonne: str
    # Ce que la case attend, lu dans son libelle : « nombre » pour un montant,
    # « texte » pour un nom, puis « code », « telephone », « email » et
    # « date » pour l'attestation. Seul « nombre » est conserve en valeur ; tout
    # le reste est du texte, et l'ecran en tire le clavier et les caracteres
    # qu'il laisse passer.
    type_saisie: str = "nombre"
    valeur: float | None = None
    texte: str | None = None
    commentaire: str | None = None


class EtatASaisir(BaseModel):
    """Une feuille a completer, avec ses cases et son avancement.

    `obligatoire` distingue ce que l'outil ne produira jamais — l'identite de
    l'etablissement et les signatures de l'attestation — de ce qu'il declare
    deja a zero et que l'on ne complete que si l'etablissement est concerne.
    """

    etat: str
    intitule: str
    cases: list[CaseFodep]
    renseignees: int
    obligatoire: bool = False


class SaisiesFodep(BaseModel):
    """Catalogue des cases a saisir et valeurs deja portees."""

    etats: list[EtatASaisir]
    total_cases: int
    total_renseignees: int


class SaisiesFodepEnregistrees(BaseModel):
    """Saisies transmises par l'ecran, et nombre de cases touchees."""

    saisies: list[CaseFodep]
    enregistrees: int = 0

