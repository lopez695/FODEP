"""Reserves de lecture d'une declaration FODEP.

L'export produit le classeur, et avec lui des remarques : ce que l'application
n'a pas su alimenter, les choix qu'elle a du faire pour loger ses donnees dans
le formulaire, les postes declares a zero. L'interface les affichait toutes
d'affilee, sous une meme phrase — « completez-les a la main avant de deposer la
declaration ». Or cette consigne n'en concerne qu'une partie : on ne complete
pas a la main une convention de report, ni un poste que l'etablissement ne
detient pas. Noyees dans la liste, les remarques qui appelaient vraiment un
geste se lisaient comme les autres, c'est-a-dire pas du tout.

Chaque reserve porte donc sa nature. C'est elle qui decide de la place et du
ton que l'ecran lui donne.
"""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, ConfigDict


class NatureReserve(str, Enum):
    """Ce que la reserve attend du declarant."""

    #: Un geste avant de transmettre : completer une saisie, reprendre un
    #: import, verifier une valeur. C'est la seule nature qui demande a agir.
    A_VERIFIER = "a_verifier"

    #: Un choix de l'application pour loger ses donnees dans le formulaire, la
    #: ou celui-ci n'offre pas la ligne attendue. Rien a faire, mais celui qui
    #: signe l'endosse : il doit l'avoir lu.
    CONVENTION = "convention"

    #: Un constat sur la declaration produite — un poste declare a zero faute
    #: d'objet, un decompte. Se lit, ne se corrige pas.
    INFORMATION = "information"


class Reserve(BaseModel):
    """Une remarque de lecture, et ce qu'elle attend."""

    # Figee, donc comparable et hachable : l'export dedoublonne ses reserves en
    # les passant par un dictionnaire, plusieurs etats pouvant faire la meme.
    model_config = ConfigDict(frozen=True)

    nature: NatureReserve
    message: str


def a_verifier(message: str) -> Reserve:
    return Reserve(nature=NatureReserve.A_VERIFIER, message=message)


def convention(message: str) -> Reserve:
    return Reserve(nature=NatureReserve.CONVENTION, message=message)


def information(message: str) -> Reserve:
    return Reserve(nature=NatureReserve.INFORMATION, message=message)
