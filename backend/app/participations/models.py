"""Modeles du suivi des participations de l'etablissement."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

# Les cinq categories sont celles des sections de l'EP34. Elles ne sont pas un
# choix de conception : le formulaire ventile ainsi les participations, et
# s'en ecarter obligerait a reclasser a l'export.
CategorieParticipation = Literal[
    "etablissement",
    "assurance",
    "autre_financiere",
    "societe_immobiliere",
    "entite_commerciale",
]

LIBELLES_CATEGORIES: dict[str, str] = {
    "etablissement": "Participations dans les etablissements",
    "assurance": "Participations dans les entreprises d'assurances",
    "autre_financiere": "Participations dans les autres entites financieres",
    "societe_immobiliere": "Participations dans les societes immobilieres",
    "entite_commerciale": "Participations dans les entites commerciales",
}


class ParticipationBase(BaseModel):
    denomination: str = Field(min_length=1, max_length=200)
    categorie: CategorieParticipation
    capital_entreprise: float = Field(default=0.0, ge=0)
    montant_brut: float = Field(default=0.0, ge=0)
    montant_net: float = Field(default=0.0, ge=0)
    commentaire: str | None = None


class ParticipationCreate(ParticipationBase):
    """Participation soumise a la creation."""


class ParticipationUpdate(BaseModel):
    """Modification partielle : seuls les champs fournis sont appliques."""

    denomination: str | None = Field(default=None, min_length=1, max_length=200)
    categorie: CategorieParticipation | None = None
    capital_entreprise: float | None = Field(default=None, ge=0)
    montant_brut: float | None = Field(default=None, ge=0)
    montant_net: float | None = Field(default=None, ge=0)
    commentaire: str | None = None


class ParticipationView(ParticipationBase):
    id: int
    cree_le: str
    modifie_le: str


class SyntheseParticipations(BaseModel):
    """Totaux par categorie et ratios prudentiels de l'EP01.

    Les trois ratios sont ceux des normes RA006 a RA008 : la plus forte
    participation individuelle rapportee au capital de son emetteur, la plus
    forte rapportee aux fonds propres de base T1, et le total des
    participations dans les entites commerciales rapporte aux fonds propres
    effectifs.
    """

    totaux_par_categorie: dict[str, float]
    total_general: float
    total_entites_commerciales: float
    ratio_max_capital_emetteur: float
    ratio_max_fonds_propres_t1: float
    ratio_global_fonds_propres_effectifs: float


# Plafonds du dispositif prudentiel. Ce ne sont pas des reglages : ils sont
# fixes par les etats eux-memes, qui calculent l'excedent a partir d'eux.
LIMITE_CAPITAL_EMETTEUR = 0.25
LIMITE_FONDS_PROPRES_BASE = 0.15
LIMITE_GLOBALE_FONDS_PROPRES_EFFECTIFS = 0.60
LIMITE_IMMOBILISATIONS_HORS_EXPLOITATION = 0.15
LIMITE_IMMOBILISATIONS_ET_PARTICIPATIONS = 1.00


class LimitePrudentielle(BaseModel):
    """Une limite de l'EP01, avec de quoi la refaire a la main.

    Un ratio seul ne se verifie pas : l'ecran affiche donc aussi son
    numerateur, son denominateur et l'etat qui les porte. Quand le
    denominateur manque — aucun fonds propres saisi, capital de l'emetteur non
    renseigne — la limite n'est pas « respectee », elle n'est pas mesurable,
    et c'est ce que dit `mesurable`.
    """

    code: str
    libelle: str
    etat: str
    numerateur: float
    numerateur_libelle: str
    denominateur: float
    denominateur_libelle: str
    observe: float
    limite: float
    mesurable: bool
    respectee: bool
    excedent: float
    concerne: str | None = None


class SyntheseParticipationsDetaillee(BaseModel):
    """Synthese des participations telle que les ecrans l'affichent.

    Elle rassemble ce que les participations doivent a d'autres donnees : les
    fonds propres, qui sont le denominateur de quatre limites sur cinq, et les
    immobilisations, que deux limites additionnent aux participations.
    """

    nombre: int
    nombre_entites_commerciales: int
    total_general: float
    total_entites_commerciales: float
    totaux_par_categorie: dict[str, float]
    libelles_categories: dict[str, str]

    fonds_propres_t1: float
    fonds_propres_effectifs: float
    date_fonds_propres: str | None
    immobilisations_nettes: float
    immobilisations_hors_exploitation_nettes: float

    limites: list[LimitePrudentielle]
    alertes: list[str]
