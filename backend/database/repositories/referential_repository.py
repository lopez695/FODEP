"""Accès ORM (SQLAlchemy) aux référentiels prudentiels.

Module pilote de la migration ORM : les 4 tables de référentiels
(baremes_ponderation, baremes_ccf, references_notation,
references_pays_souverains) sont lues/écrites via SQLAlchemy au lieu de SQL
brut (voir database/orm.py et database/orm_models/referentiels.py). Les
signatures publiques de ReferentialRepository sont inchangées : aucun appelant
(services.py, routes.py, calculations.py) n'a besoin d'être modifié.

Les autres repositories (exposure, crm, off_balance, report) restent en SQL
brut pour l'instant ; ils seront migrés progressivement selon ce même pattern.
"""

from __future__ import annotations

import unicodedata
from typing import Any

from sqlalchemy import delete, func, select

from app.core.calculations import bucketize_rating
from app.referentiels.models import CcfReference, RatingReference, ReferentialBundle, RiskWeightReference
from database.orm import orm_session
from database.orm_models.referentiels import (
    BaremeCcfOrm,
    BaremePonderationOrm,
    ReferenceNotationOrm,
    ReferencePaysSouverainOrm,
)


def _normalize_key(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.strip().lower())
    normalized = "".join(char for char in normalized if not unicodedata.combining(char))
    return " ".join(normalized.split())


class ReferentialDataMissingError(ValueError):
    """Levee quand un bareme prudentiel requis n'a jamais ete configure.

    Sous-classe de ValueError pour rester compatible avec la gestion
    d'erreurs deja en place dans les routes (ValueError -> HTTP 400),
    sans avoir a modifier chaque route appelante.
    """


class ReferentialRepository:
    """Fournit les référentiels depuis SQLite via SQLAlchemy."""

    def list_risk_weight_references(self) -> list[RiskWeightReference]:
        with orm_session() as session:
            rows = (
                session.execute(
                    select(BaremePonderationOrm).order_by(
                        BaremePonderationOrm.segment, BaremePonderationOrm.id
                    )
                )
                .scalars()
                .all()
            )
            return [
                RiskWeightReference(
                    id=row.id,
                    segment=row.segment,
                    rating=row.notation,
                    risk_weight=row.ponderation,
                    approach=row.approche,
                )
                for row in rows
            ]

    def list_ccf_references(self) -> list[CcfReference]:
        with orm_session() as session:
            rows = session.execute(select(BaremeCcfOrm).order_by(BaremeCcfOrm.id)).scalars().all()
            return [
                CcfReference(id=row.id, engagement_type=row.type_engagement, ccf=row.ccf)
                for row in rows
            ]

    def list_rating_references(self) -> list[RatingReference]:
        with orm_session() as session:
            rows = (
                session.execute(
                    select(ReferenceNotationOrm).order_by(
                        ReferenceNotationOrm.ordre_tri, ReferenceNotationOrm.id
                    )
                )
                .scalars()
                .all()
            )
            return [
                RatingReference(
                    id=row.id,
                    label=row.libelle,
                    description=row.description,
                    sort_order=row.ordre_tri,
                )
                for row in rows
            ]

    def get_referential_bundle(self) -> ReferentialBundle:
        return ReferentialBundle(
            risk_weights=self.list_risk_weight_references(),
            ccf_table=self.list_ccf_references(),
            ratings=self.list_rating_references(),
        )

    def replace_all(
        self,
        *,
        risk_weights: list[dict[str, Any]],
        ccf_table: list[dict[str, Any]],
        ratings: list[dict[str, Any]],
        country_ratings: list[dict[str, Any]] | None = None,
        connection=None,  # conservé pour compatibilité de signature (non utilisé, aucun appelant ORM externe)
    ) -> None:
        with orm_session() as session:
            session.execute(delete(ReferencePaysSouverainOrm))
            session.execute(delete(ReferenceNotationOrm))
            session.execute(delete(BaremeCcfOrm))
            session.execute(delete(BaremePonderationOrm))

            if risk_weights:
                session.add_all(
                    [
                        BaremePonderationOrm(
                            id=item["id"],
                            segment=item["segment"],
                            notation=item["rating"],
                            ponderation=item["risk_weight"],
                            approche=item["approach"],
                        )
                        for item in risk_weights
                    ]
                )
            if ccf_table:
                session.add_all(
                    [
                        BaremeCcfOrm(
                            id=item["id"],
                            type_engagement=item["engagement_type"],
                            ccf=item["ccf"],
                        )
                        for item in ccf_table
                    ]
                )
            if ratings:
                session.add_all(
                    [
                        ReferenceNotationOrm(
                            id=item["id"],
                            libelle=item["label"],
                            description=item["description"],
                            ordre_tri=item["sort_order"],
                        )
                        for item in ratings
                    ]
                )
            if country_ratings:
                session.add_all(
                    [
                        ReferencePaysSouverainOrm(
                            pays=item["country"],
                            notation_souveraine=item["sovereign_rating"],
                            ponderation=item["risk_weight"],
                        )
                        for item in country_ratings
                    ]
                )

    def get_risk_weight(self, segment: str, rating: str) -> float:
        references = self.list_risk_weight_references()
        if not references:
            raise ReferentialDataMissingError(
                "Aucun bareme de ponderation n'est configure (table "
                "baremes_ponderation vide) : impossible de determiner une "
                "ponderation prudentielle fiable. Configurez les "
                "referentiels avant de poursuivre."
            )
        target_bucket = bucketize_rating(rating)
        target_candidates = {target_bucket, target_bucket.replace(" ", ""), rating}
        exact = next(
            (
                reference.risk_weight
                for reference in references
                if _normalize_key(reference.segment) == _normalize_key(segment)
                and reference.rating in target_candidates
            ),
            None,
        )
        if exact is not None:
            return exact
        if _normalize_key(segment) == "banques":
            for option in ("Banques >3m", "Banques <=3m"):
                found = next(
                    (
                        reference.risk_weight
                        for reference in references
                        if _normalize_key(reference.segment) == _normalize_key(option)
                        and reference.rating in target_candidates
                    ),
                    None,
                )
                if found is not None:
                    return found
        if _normalize_key(segment) == "particuliers":
            found = next(
                (
                    reference.risk_weight
                    for reference in references
                    if _normalize_key(reference.segment) == "entreprises"
                    and reference.rating in target_candidates
                ),
                None,
            )
            if found is not None:
                return found
        fallback = next(
            (
                reference.risk_weight
                for reference in references
                if _normalize_key(reference.segment) == "entreprises"
                and reference.rating in target_candidates
            ),
            None,
        )
        return fallback if fallback is not None else 1.0

    def get_ccf(self, engagement_type: str) -> float:
        references = self.list_ccf_references()
        if not references:
            raise ReferentialDataMissingError(
                "Aucun bareme de CCF n'est configure (table baremes_ccf "
                "vide) : impossible de determiner un facteur de conversion "
                "fiable. Configurez les referentiels avant de poursuivre."
            )
        lowered = _normalize_key(engagement_type)
        for reference in references:
            if _normalize_key(reference.engagement_type) == lowered:
                return reference.ccf
        return 1.0

    def is_empty(self) -> bool:
        with orm_session() as session:
            total = session.execute(
                select(func.count()).select_from(BaremePonderationOrm)
            ).scalar_one()
        return total == 0


referential_repository = ReferentialRepository()
