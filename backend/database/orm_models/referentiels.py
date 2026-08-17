"""Modèles ORM pour les référentiels prudentiels.

Mappe les 4 tables définies dans database/schema.sql (lignes ~228-253) :
baremes_ponderation, baremes_ccf, references_notation,
references_pays_souverains. Module pilote de la migration SQLAlchemy —
aucune jointure, CRUD simple, sert de gabarit pour les modules suivants.
"""

from __future__ import annotations

from sqlalchemy import Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from database.orm import Base


class BaremePonderationOrm(Base):
    """Barème de pondération prudentielle par segment / notation."""

    __tablename__ = "baremes_ponderation"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    segment: Mapped[str] = mapped_column(String, nullable=False)
    notation: Mapped[str] = mapped_column(String, nullable=False)
    ponderation: Mapped[float] = mapped_column(Float, nullable=False)
    approche: Mapped[str] = mapped_column(String, nullable=False)


class BaremeCcfOrm(Base):
    """Facteur de conversion de crédit (CCF) par nature d'engagement hors bilan."""

    __tablename__ = "baremes_ccf"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    type_engagement: Mapped[str] = mapped_column(String, nullable=False)
    ccf: Mapped[float] = mapped_column(Float, nullable=False)


class ReferenceNotationOrm(Base):
    """Notation disponible dans l'application (échelle affichée à l'utilisateur)."""

    __tablename__ = "references_notation"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    libelle: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=False)
    ordre_tri: Mapped[int] = mapped_column(Integer, nullable=False)


class ReferencePaysSouverainOrm(Base):
    """Notation souveraine et pondération associée par pays."""

    __tablename__ = "references_pays_souverains"

    pays: Mapped[str] = mapped_column(String, primary_key=True)
    notation_souveraine: Mapped[str] = mapped_column(String, nullable=False)
    ponderation: Mapped[float] = mapped_column(Float, nullable=False)
