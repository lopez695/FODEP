"""Modeles du module ICAAP / PIEAFP.

Le PIEAFP part du Pilier 1 et lui ajoute ce que la formule standard ne capte
pas. Ce premier ecran porte donc le socle : ce que le dispositif exige, ce que
l'etablissement detient, et l'ecart entre les deux. Les add-ons du Pilier 2
(concentration, residuel, taux du portefeuille bancaire, liquidite) viendront
s'y adosser -- ils ne remplacent jamais ce socle, ils s'y ajoutent.
"""

from __future__ import annotations

from pydantic import BaseModel, Field

from app.dashboard.models import FondsPropresDetail

BROUILLON = "brouillon"
VALIDE = "valide"
TRANSMIS = "transmis"


class CycleIcaap(BaseModel):
    """Ou en est le cycle annuel du PIEAFP, pour un exercice donne."""

    exercice: int
    statut: str = BROUILLON

    #: Date a laquelle l'organe deliberant a valide. Le rapport PIEAFP est un
    #: document de gouvernance : sans validation, il n'engage personne.
    date_validation: str | None = None

    #: Organe qui a valide -- le Conseil d'administration, en principe.
    organe: str = ""

    version: int = 1
    commentaire: str = ""


class StatutCycleUpdate(BaseModel):
    """Changement d'etape du cycle."""

    statut: str = Field(..., pattern=f"^({BROUILLON}|{VALIDE}|{TRANSMIS})$")
    date_validation: str | None = None
    organe: str = ""
    commentaire: str = ""


class ExigenceRisque(BaseModel):
    """Ce qu'un type de risque consomme en fonds propres, au titre du Pilier 1."""

    code: str
    libelle: str

    #: Actifs ponderes des risques. Pour le marche et l'operationnel, le
    #: dispositif (§90) pose APR = 12,5 x exigence : la conversion est faite en
    #: amont, ces montants sont deja des equivalents APR.
    apr: float = 0.0

    #: Exigence de fonds propres correspondante, soit 8 % des APR.
    exigence: float = 0.0

    #: Part des APR totaux.
    part: float = 0.0

    #: Ce que le PIEAFP devra examiner en plus de la formule standard.
    angle_pilier2: str = ""


class NiveauRatio(BaseModel):
    """Un ratio reglementaire, confronte a ses deux seuils.

    Deux seuils, parce que le dispositif en pose deux : le minimum du Titre III
    (§91), et ce meme minimum augmente du coussin de conservation. C'est le
    second que l'EP01 de la declaration mesure -- 7,5 %, 8,5 % et 11,5 % pour
    les trois ratios de fonds propres. N'en montrer qu'un ferait croire a une
    marge que la declaration ne reconnait pas.
    """

    code: str
    libelle: str

    #: En points de pourcentage (9,0 pour 9 %), comme le reste de l'outil.
    observe: float = 0.0
    minimum: float = 0.0

    #: Minimum + coussin de conservation. Egal au minimum pour le levier, que
    #: le coussin ne majore pas.
    exigence_avec_coussin: float = 0.0

    ecart_minimum: float = 0.0
    ecart_avec_coussin: float = 0.0

    #: « respectee », « sous_coussin » ou « depassee ».
    situation: str = "respectee"

    #: Montant de fonds propres qu'exige le seuil avec coussin.
    fonds_propres_requis: float = 0.0


class ExigenceGlobale(BaseModel):
    """Le socle a couvrir avant toute exigence interne.

    Le PIEAFP ne remplace jamais ce socle : les cibles internes doivent lui
    etre superieures.
    """

    apr_total: float = 0.0
    minimum_solvabilite: float = 0.0
    coussin_conservation: float = 0.0

    #: Variable, active par la Banque Centrale selon le cycle du credit. Non
    #: parametrable a ce stade : l'ecran des coussins prudentiels le portera.
    coussin_contracyclique: float = 0.0

    #: Applicable aux etablissements d'importance systemique regionale.
    coussin_systemique: float = 0.0

    exigence_globale: float = 0.0
    fonds_propres_requis: float = 0.0
    fonds_propres_disponibles: float = 0.0

    #: Positif = matelas au-dela de l'exigence globale ; negatif = deficit.
    marge: float = 0.0


class CapitalReglementaire(BaseModel):
    """Le Pilier 1 tel que le PIEAFP le prend pour point de depart."""

    cycle: CycleIcaap
    fonds_propres: FondsPropresDetail
    exigences: list[ExigenceRisque] = []
    apr_total: float = 0.0
    exigence_totale: float = 0.0
    ratios: list[NiveauRatio] = []
    exigence_globale: ExigenceGlobale
    assiette_levier: float = 0.0

    #: Ce qui empeche de conclure. Le dispositif fait de l'integrite des
    #: donnees un point de controle explicite (composante 2) : un socle calcule
    #: sur une brique absente doit le dire, pas afficher un zero credible.
    avertissements: list[str] = []
