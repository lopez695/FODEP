"""Groupes de clients lies : constitution et rattachement des contreparties.

Sans groupe constitue, la division des risques traite chaque contrepartie
comme un groupe a elle seule, ce qui sous-estime les concentrations, et
l'etat EP30 reste vide faute de clients a detailler.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status

from app.groupes_clients.models import (
    ContrepartieView,
    GroupeCreate,
    GroupeUpdate,
    GroupeView,
    MembreGroupe,
    RattachementUpdate,
)
from database.connection import database_manager


def _horodatage() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _membres(connexion, groupe_id: int) -> list[MembreGroupe]:
    lignes = connexion.execute(
        """
        SELECT id, nom, pays, categorie_lien, numero_centrale_risques,
               secteur_activite, categorie_partie_liee
        FROM contreparties WHERE groupe_id = ? ORDER BY nom
        """,
        (groupe_id,),
    ).fetchall()
    return [MembreGroupe(**dict(ligne)) for ligne in lignes]


def lister_groupes() -> list[GroupeView]:
    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT id, nom, numero_centrale_risques, cree_le, modifie_le
            FROM groupes_clients ORDER BY nom
            """
        ).fetchall()
        return [
            GroupeView(**dict(ligne), membres=_membres(connexion, int(ligne["id"])))
            for ligne in lignes
        ]


def creer_groupe(payload: GroupeCreate) -> GroupeView:
    horodatage = _horodatage()
    with database_manager.transaction() as connexion:
        existant = connexion.execute(
            "SELECT 1 FROM groupes_clients WHERE nom = ?", (payload.nom.strip(),)
        ).fetchone()
        if existant is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "GROUPE_DEJA_EXISTANT",
                    "message": f"Un groupe nomme « {payload.nom} » existe deja.",
                },
            )
        curseur = connexion.execute(
            """
            INSERT INTO groupes_clients(
                nom, numero_centrale_risques, cree_le, modifie_le
            ) VALUES (?, ?, ?, ?)
            """,
            (
                payload.nom.strip(),
                payload.numero_centrale_risques,
                horodatage,
                horodatage,
            ),
        )
        identifiant = int(curseur.lastrowid or 0)
    return _lire_ou_404(identifiant)


def modifier_groupe(identifiant: int, payload: GroupeUpdate) -> GroupeView:
    champs = payload.model_dump(exclude_unset=True)
    if not champs:
        return _lire_ou_404(identifiant)
    affectations = ", ".join(f"{nom} = ?" for nom in champs)
    with database_manager.transaction() as connexion:
        # Le nom d'un groupe est unique : renommer vers un nom deja pris doit
        # se dire clairement, plutot que de remonter une violation de
        # contrainte que l'ecran ne saurait pas expliquer.
        nouveau_nom = champs.get("nom")
        if nouveau_nom:
            collision = connexion.execute(
                "SELECT 1 FROM groupes_clients WHERE nom = ? AND id <> ?",
                (str(nouveau_nom).strip(), identifiant),
            ).fetchone()
            if collision is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "GROUPE_DEJA_EXISTANT",
                        "message": f"Un autre groupe porte deja le nom « {nouveau_nom} ».",
                    },
                )
        curseur = connexion.execute(
            f"UPDATE groupes_clients SET {affectations}, modifie_le = ? WHERE id = ?",
            list(champs.values()) + [_horodatage(), identifiant],
        )
        if curseur.rowcount == 0:
            raise _introuvable(identifiant)
    return _lire_ou_404(identifiant)


def supprimer_groupe(identifiant: int) -> None:
    """Supprime un groupe et detache ses membres, sans les effacer."""

    with database_manager.transaction() as connexion:
        connexion.execute(
            """
            UPDATE contreparties SET groupe_id = NULL, categorie_lien = NULL
            WHERE groupe_id = ?
            """,
            (identifiant,),
        )
        curseur = connexion.execute(
            "DELETE FROM groupes_clients WHERE id = ?", (identifiant,)
        )
        if curseur.rowcount == 0:
            raise _introuvable(identifiant)


def lister_contreparties(sans_groupe: bool = False) -> list[ContrepartieView]:
    """Contreparties du portefeuille, avec leur groupe eventuel."""

    filtre = "WHERE c.groupe_id IS NULL" if sans_groupe else ""
    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            f"""
            SELECT c.id, c.nom, c.pays, c.categorie_lien,
                   c.numero_centrale_risques, c.secteur_activite,
                   c.categorie_partie_liee,
                   c.groupe_id, g.nom AS groupe_nom
            FROM contreparties c
            LEFT JOIN groupes_clients g ON g.id = c.groupe_id
            {filtre}
            ORDER BY c.nom
            """
        ).fetchall()
    return [ContrepartieView(**dict(ligne)) for ligne in lignes]


def rattacher_contrepartie(
    identifiant: str, payload: RattachementUpdate
) -> ContrepartieView:
    champs = payload.model_dump(exclude_unset=True)
    if not champs:
        return _lire_contrepartie_ou_404(identifiant)

    if champs.get("groupe_id") is not None:
        with database_manager.read_connection() as connexion:
            existe = connexion.execute(
                "SELECT 1 FROM groupes_clients WHERE id = ?", (champs["groupe_id"],)
            ).fetchone()
        if existe is None:
            raise _introuvable(int(champs["groupe_id"]))

    affectations = ", ".join(f"{nom} = ?" for nom in champs)
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            f"UPDATE contreparties SET {affectations}, modifie_le = ? WHERE id = ?",
            list(champs.values()) + [_horodatage(), identifiant],
        )
        if curseur.rowcount == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "CONTREPARTIE_INTROUVABLE",
                    "message": f"Aucune contrepartie ne porte l'identifiant {identifiant}.",
                },
            )
    return _lire_contrepartie_ou_404(identifiant)


def _introuvable(identifiant: int) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail={
            "code": "GROUPE_INTROUVABLE",
            "message": f"Aucun groupe ne porte l'identifiant {identifiant}.",
        },
    )


def _lire_ou_404(identifiant: int) -> GroupeView:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            """
            SELECT id, nom, numero_centrale_risques, cree_le, modifie_le
            FROM groupes_clients WHERE id = ?
            """,
            (identifiant,),
        ).fetchone()
        if ligne is None:
            raise _introuvable(identifiant)
        return GroupeView(**dict(ligne), membres=_membres(connexion, identifiant))


def _lire_contrepartie_ou_404(identifiant: str) -> ContrepartieView:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            """
            SELECT c.id, c.nom, c.pays, c.categorie_lien,
                   c.numero_centrale_risques, c.secteur_activite,
                   c.categorie_partie_liee,
                   c.groupe_id, g.nom AS groupe_nom
            FROM contreparties c
            LEFT JOIN groupes_clients g ON g.id = c.groupe_id
            WHERE c.id = ?
            """,
            (identifiant,),
        ).fetchone()
    if ligne is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "CONTREPARTIE_INTROUVABLE",
                "message": f"Aucune contrepartie ne porte l'identifiant {identifiant}.",
            },
        )
    return ContrepartieView(**dict(ligne))
