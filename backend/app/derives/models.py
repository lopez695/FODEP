"""Modeles du registre des instruments derives.

Le vocabulaire est celui de l'EP11, pas celui d'une salle des marches : cinq
natures de sous-jacent, trois tranches de duree residuelle, cinq categories de
contrepartie. Le formulaire ventile ainsi, et nommer les choses autrement
obligerait a traduire a l'export -- c'est-a-dire a deux endroits ou se tromper
au lieu d'un.

Un contrat designe une contrepartie du portefeuille par son identifiant. Son
nom et sa categorie ne se saisissent pas : ils viennent de la fiche, celle-la
meme sur laquelle le moteur de calcul pondere les prets au meme tiers.

Il peut aussi designer ce qu'il couvre -- un credit, une obligation, une
action. Ce n'est pas la meme chose que la contrepartie : l'EP11 ventile le
signataire du contrat, pas l'emetteur du titre.
"""

from __future__ import annotations

from datetime import date
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.core.calculations import DEVISES_CONVERTIBLES

# Les cinq blocs de l'EP11, dans l'ordre ou le formulaire les imprime.
NatureDerive = Literal[
    "taux",
    "change_or",
    "titres_propriete",
    "metaux_precieux",
    "autres_produits_de_base",
]

LIBELLES_NATURES: dict[str, str] = {
    "taux": "Engagements sur instruments de taux d'interet",
    "change_or": "Engagements sur instruments de taux de change et l'or",
    "titres_propriete": "Engagements sur titres de propriete",
    "metaux_precieux": "Engagements sur metaux precieux (excepte l'or)",
    "autres_produits_de_base": "Engagements sur autres produits de base",
}

# Les cinq colonnes de ventilation de l'EP11 (H a L). Ce sont les memes lettres
# que la nomenclature FODEP donne aux categories d'expositions -- « a »
# souverains, « e » entreprises -- et les memes que les etats EP12 a EP16.
CategorieContrepartieDerive = Literal["a", "b", "c", "d", "e"]

LIBELLES_CATEGORIES_CONTREPARTIE: dict[str, str] = {
    "a": "Souverains",
    "b": "Organismes publics hors administration centrale",
    "c": "Banques multilaterales de developpement",
    "d": "Institutions financieres",
    "e": "Entreprises",
}

#: Ce a quoi le contrat se rattache : le credit d'un client qu'il couvre, une
#: obligation ou une action detenue, ou rien de tel -- une devise, un indice,
#: une matiere premiere.
TypeSousJacent = Literal["credit", "obligation", "action", "autre"]

LIBELLES_SOUS_JACENTS: dict[str, str] = {
    "credit": "un credit",
    "obligation": "une obligation",
    "action": "une action",
    "autre": "aucune position",
}

#: La nature que le sous-jacent impose. Un derive sur une obligation porte sur
#: les taux d'interet, un derive sur une action sur les titres de propriete :
#: les ranger ailleurs les declarerait sous la mauvaise ponderation.
NATURE_IMPOSEE: dict[str, str] = {
    "obligation": "taux",
    "action": "titres_propriete",
}

# Les trois lignes de chaque bloc, dans l'ordre du formulaire. La borne est
# exprimee en annees de duree residuelle ; `None` ferme la derniere tranche.
TRANCHES_DUREE: tuple[tuple[str, str, float | None], ...] = (
    ("moins_1_an", "Duree < 1 an", 1.0),
    ("1_a_5_ans", "Duree > 1 an jusqu'a 5 ans", 5.0),
    ("plus_5_ans", "Duree > 5 ans", None),
)

TrancheDuree = Literal["moins_1_an", "1_a_5_ans", "plus_5_ans"]

#: Jours d'une annee, pour ramener une echeance a une duree. Le formulaire ne
#: precise pas de convention ; l'annee civile moyenne evite qu'un contrat a
#: exactement cinq ans bascule de tranche selon les bissextiles traversees.
JOURS_PAR_AN = 365.25


def tranche_de_duree(echeance: date, reference: date) -> str:
    """Tranche de l'EP11 ou tombe un contrat, a la date d'arrete retenue.

    Un contrat deja echu ne disparait pas du registre : il tombe dans la
    premiere tranche, ou son notionnel est pondere a zero pour les instruments
    de taux. Le supprimer serait perdre une trace ; le declarer ailleurs serait
    le declarer faux.
    """

    annees = (echeance - reference).days / JOURS_PAR_AN
    for cle, _, borne in TRANCHES_DUREE:
        if borne is None or annees <= borne:
            return cle
    return TRANCHES_DUREE[-1][0]


def _verifier_devise(devise: str) -> str:
    """Une devise que l'outil sait convertir, ou un refus.

    `convert_currency_amount` convertit toute devise inconnue au taux de repli
    1,0 : un contrat en livres partirait dans l'EP11 comme s'il etait libelle en
    francs. L'ecran propose une liste fermee ; la validation tient aussi pour un
    appel direct a l'API.
    """

    code = devise.strip().upper()
    if code not in DEVISES_CONVERTIBLES:
        raise ValueError(
            f"Devise {code} non prise en charge : l'outil ne sait convertir en "
            "FCFA que " + ", ".join(sorted(DEVISES_CONVERTIBLES)) + "."
        )
    return code


class DeriveSaisie(BaseModel):
    """Ce que le declarant porte sur un contrat, et rien d'autre."""

    #: Identifiant de la contrepartie dans le portefeuille (`EXP-2026-00001`).
    #: C'est lui qui relie le derive au tiers : son nom, sa categorie et sa
    #: notation se lisent sur la fiche.
    contrepartie_id: str = Field(min_length=1, max_length=64)
    nature: NatureDerive
    #: Ce que le contrat couvre ; « autre » quand il ne porte sur aucune
    #: position detenue.
    sous_jacent_type: TypeSousJacent = "autre"
    #: Identifiant de l'exposition, ISIN ou ticker selon le type.
    sous_jacent_ref: str | None = Field(default=None, max_length=200)
    type_contrat: str | None = Field(default=None, max_length=100)
    devise: str = Field(default="XOF", min_length=3, max_length=3)
    montant_notionnel: float = Field(default=0.0, ge=0)
    # Le cout de remplacement est la valeur de marche du contrat lorsqu'elle est
    # en faveur de l'etablissement. Une valeur negative ne se declare pas : le
    # formulaire additionne (a) et (d), et y porter un nombre negatif reduirait
    # l'exposition d'un contrat qui ne rapporte rien.
    cout_remplacement: float = Field(default=0.0, ge=0)
    date_conclusion: date | None = None
    date_echeance: date
    commentaire: str | None = None

    @field_validator("devise")
    @classmethod
    def _devise_convertible(cls, devise: str) -> str:
        return _verifier_devise(devise)


class DeriveCreate(DeriveSaisie):
    """Contrat soumis a la creation."""


class DeriveUpdate(BaseModel):
    """Modification partielle : seuls les champs fournis sont appliques."""

    contrepartie_id: str | None = Field(default=None, min_length=1, max_length=64)
    nature: NatureDerive | None = None
    sous_jacent_type: TypeSousJacent | None = None
    sous_jacent_ref: str | None = Field(default=None, max_length=200)
    type_contrat: str | None = Field(default=None, max_length=100)
    devise: str | None = Field(default=None, min_length=3, max_length=3)
    montant_notionnel: float | None = Field(default=None, ge=0)
    cout_remplacement: float | None = Field(default=None, ge=0)
    date_conclusion: date | None = None
    date_echeance: date | None = None
    commentaire: str | None = None

    @field_validator("devise")
    @classmethod
    def _devise_convertible(cls, devise: str | None) -> str | None:
        return None if devise is None else _verifier_devise(devise)


class DeriveView(BaseModel):
    id: int
    #: `None` pour un contrat enregistre avant le rattachement aux contreparties.
    contrepartie_id: str | None = None
    #: Nom lu sur la fiche de la contrepartie, ou a defaut recopie sur le
    #: contrat au jour de l'enregistrement.
    contrepartie: str
    #: Colonne de ventilation de l'EP11, deduite de la categorie prudentielle.
    categorie_contrepartie: CategorieContrepartieDerive
    categorie_prudentielle: str | None = None
    notation: str | None = None
    #: Vrai quand la categorie prudentielle n'a pas de colonne sur l'EP11
    #: (clientele de detail, immobilier, creances en souffrance...) : le
    #: contrat se range alors sous « Entreprises », repli du formulaire.
    hors_ep11: bool = False

    sous_jacent_type: TypeSousJacent = "autre"
    sous_jacent_ref: str | None = None
    sous_jacent_libelle: str | None = None

    nature: NatureDerive
    type_contrat: str | None = None
    devise: str = "XOF"
    montant_notionnel: float = 0.0
    cout_remplacement: float = 0.0
    date_conclusion: date | None = None
    date_echeance: date
    commentaire: str | None = None
    cree_le: str
    modifie_le: str

    #: Tranche de duree residuelle a ce jour, telle que l'EP11 la nomme. Elle
    #: est calculee et non stockee : elle change avec le temps, et l'ecran doit
    #: montrer celle d'aujourd'hui, pas celle du jour de la saisie.
    tranche: TrancheDuree
    #: Exposition au sens de l'EP11 : (a) + (b x c). La ponderation vient du
    #: formulaire, releve a l'export ; la reproduire ici serait la coder deux
    #: fois. Elle vaut donc `None` tant que l'agregation n'a pas eu lieu.
    exposition: float | None = None


class ContrepartieDerive(BaseModel):
    """Une contrepartie du portefeuille, telle que le selecteur la propose.

    L'identifiant est affiche a cote du nom : deux tiers peuvent porter le meme,
    et c'est par lui qu'on fait la correspondance avec le reste de l'outil.
    """

    id: str
    nom: str
    pays: str | None = None
    categorie_prudentielle: str | None = None
    #: Colonne de l'EP11 ou tomberait un derive sur ce tiers.
    categorie_ep11: CategorieContrepartieDerive
    hors_ep11: bool = False
    notation: str | None = None


class CreditCouvrable(BaseModel):
    """Un credit du portefeuille, que le client peut couvrir par un derive.

    Il porte sa contrepartie : le client qui emprunte est aussi celui qui signe
    la couverture, et c'est lui que l'EP11 ventilera.
    """

    id: str
    contrepartie_id: str
    contrepartie: str
    categorie_prudentielle: str | None = None
    categorie_ep11: CategorieContrepartieDerive
    hors_ep11: bool = False
    notation: str | None = None
    montant_brut: float = 0.0
    devise: str = "XOF"
    date_echeance: date | None = None
    statut: str | None = None


class ObligationDetenue(BaseModel):
    """Une obligation du portefeuille de marche.

    Son emetteur n'est PAS la contrepartie d'un derive qui la couvre : le
    contrat est signe avec une banque ou un client, et c'est eux que l'EP11
    ventile.
    """

    isin: str
    emetteur: str
    devise: str = "XOF"
    date_echeance: date
    valeur_nominale: float = 0.0
    quantite: int = 0
    taux_coupon_pct: float = 0.0


class ActionDetenue(BaseModel):
    """Une action du portefeuille de marche."""

    ticker: str
    libelle: str
    secteur: str | None = None
    quantite: int = 0


class SousJacents(BaseModel):
    """Ce a quoi un derive peut se rattacher, par onglet du formulaire."""

    credits: list[CreditCouvrable]
    obligations: list[ObligationDetenue]
    actions: list[ActionDetenue]
    #: Ce qui n'a pas pu etre lu -- un portefeuille de marche illisible ne doit
    #: pas empecher de saisir un derive sur un credit.
    alertes: list[str] = []


class LigneEp11(BaseModel):
    """Une des quinze lignes de l'EP11, telle que le registre la remplit."""

    code: str
    nature: str
    tranche: str
    libelle: str
    nombre_contrats: int
    cout_remplacement: float
    montant_notionnel: float
    ponderation: float
    notionnel_pondere: float
    exposition: float
    ventilation: dict[str, float]


class SyntheseDerives(BaseModel):
    """Ce que le registre declarera sur l'EP11.

    L'ecran affiche l'etat tel qu'il partira, et non une somme de contrats :
    c'est la seule facon de verifier une saisie avant de transmettre.
    """

    nombre: int
    total_notionnel: float
    total_cout_remplacement: float
    total_exposition: float
    lignes: list[LigneEp11]
    libelles_natures: dict[str, str]
    libelles_categories: dict[str, str]
    alertes: list[str]
