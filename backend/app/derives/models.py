"""Modeles du registre des instruments derives.

Le vocabulaire est celui de l'EP11, pas celui d'une salle des marches : cinq
natures de sous-jacent, trois tranches de duree residuelle, cinq categories de
contrepartie. Le formulaire ventile ainsi, et nommer les choses autrement
obligerait a traduire a l'export -- c'est-a-dire a deux endroits ou se tromper
au lieu d'un.
"""

from __future__ import annotations

from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

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


class DeriveBase(BaseModel):
    contrepartie: str = Field(min_length=1, max_length=200)
    categorie_contrepartie: CategorieContrepartieDerive = "d"
    nature: NatureDerive
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


class DeriveCreate(DeriveBase):
    """Contrat soumis a la creation."""


class DeriveUpdate(BaseModel):
    """Modification partielle : seuls les champs fournis sont appliques."""

    contrepartie: str | None = Field(default=None, min_length=1, max_length=200)
    categorie_contrepartie: CategorieContrepartieDerive | None = None
    nature: NatureDerive | None = None
    type_contrat: str | None = Field(default=None, max_length=100)
    devise: str | None = Field(default=None, min_length=3, max_length=3)
    montant_notionnel: float | None = Field(default=None, ge=0)
    cout_remplacement: float | None = Field(default=None, ge=0)
    date_conclusion: date | None = None
    date_echeance: date | None = None
    commentaire: str | None = None


class DeriveView(DeriveBase):
    id: int
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
