"""Modeles des groupes de clients lies (etat EP30)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

# Natures de lien retenues par le dispositif prudentiel pour rattacher deux
# contreparties a un meme groupe. Le formulaire attend cette qualification en
# clair : elle explique pourquoi les risques sont additionnes.
CategorieLien = Literal[
    "controle_de_droit",
    "controle_de_fait",
    "dependance_economique",
]

LIBELLES_LIENS: dict[str, str] = {
    "controle_de_droit": "Controle de droit",
    "controle_de_fait": "Controle de fait",
    "dependance_economique": "Dependance economique",
}


# Categories de parties liees, dans l'ordre des colonnes des etats EP38 et
# EP39. Une contrepartie sans categorie n'est pas une partie liee.
CategoriePartieLiee = Literal[
    "actionnaire",
    "organe_deliberant",
    "organe_executif",
    "commissaire_comptes",
    "personnel_direction",
    "cadre",
    "personnel_execution",
    "autre_partie_liee",
]

LIBELLES_PARTIES_LIEES: dict[str, str] = {
    "actionnaire": "Actionnaire detenant au moins 10 %",
    "organe_deliberant": "Membre de l'organe deliberant",
    "organe_executif": "Membre de l'organe executif",
    "commissaire_comptes": "Commissaire aux comptes",
    "personnel_direction": "Personnel de direction",
    "cadre": "Cadre moyen ou superieur",
    "personnel_execution": "Personnel d'execution",
    "autre_partie_liee": "Autre partie liee",
}


# Secteurs d'activites proposes pour l'EP30. La liste suit le decoupage par
# branche d'activite usuel dans l'UMOA ; elle sert de commodite de saisie et
# non de contrainte : une contrepartie dont le secteur n'y figure pas se
# renseigne en clair, l'etat n'attendant qu'un libelle.
SECTEURS_ACTIVITE: tuple[str, ...] = (
    "Agriculture, elevage, sylviculture",
    "Peche et aquaculture",
    "Industries extractives",
    "Industries manufacturieres",
    "Agro-industrie",
    "Electricite, gaz et eau",
    "Batiment et travaux publics",
    "Commerce de gros et de detail",
    "Transports et entreposage",
    "Hebergement et restauration",
    "Information et communication",
    "Activites financieres et d'assurance",
    "Activites immobilieres",
    "Activites specialisees, scientifiques et techniques",
    "Services administratifs et de soutien",
    "Administration publique",
    "Enseignement",
    "Sante humaine et action sociale",
    "Arts, spectacles et loisirs",
    "Autres services",
    "Menages et particuliers",
)


class GroupeBase(BaseModel):
    nom: str = Field(min_length=1, max_length=200)
    numero_centrale_risques: str | None = Field(default=None, max_length=50)


class GroupeCreate(GroupeBase):
    """Groupe soumis a la creation."""


class GroupeUpdate(BaseModel):
    nom: str | None = Field(default=None, min_length=1, max_length=200)
    numero_centrale_risques: str | None = Field(default=None, max_length=50)


class MembreGroupe(BaseModel):
    """Contrepartie rattachee a un groupe, avec son identification EP30."""

    id: str
    nom: str
    pays: str | None = None
    categorie_lien: CategorieLien | None = None
    numero_centrale_risques: str | None = None
    secteur_activite: str | None = None
    categorie_partie_liee: CategoriePartieLiee | None = None


class GroupeView(GroupeBase):
    id: int
    cree_le: str
    modifie_le: str
    membres: list[MembreGroupe] = Field(default_factory=list)


class RattachementUpdate(BaseModel):
    """Rattachement d'une contrepartie, et son identification reglementaire.

    `groupe_id` a None detache la contrepartie de son groupe.
    """

    groupe_id: int | None = None
    categorie_lien: CategorieLien | None = None
    numero_centrale_risques: str | None = Field(default=None, max_length=50)
    secteur_activite: str | None = Field(default=None, max_length=200)
    categorie_partie_liee: CategoriePartieLiee | None = None


class ContrepartieView(MembreGroupe):
    """Contrepartie du portefeuille, avec son groupe eventuel."""

    groupe_id: int | None = None
    groupe_nom: str | None = None
