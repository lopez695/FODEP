"""Identification des contreparties reprise du classeur d'import.

Le FODEP exige, pour ses etats EP30, EP38 et EP39, des donnees qui decrivent
la contrepartie et non l'exposition : son numero a la Centrale des risques,
son secteur, son groupe de clients lies et, le cas echeant, sa qualite
d'actionnaire ou de dirigeant.

Ces colonnes sont donc traitees a part, apres l'import des expositions, plutot
qu'ajoutees au modele `ExposureCreate` que traverse tout le calcul prudentiel.
Une contrepartie apparaissant sur plusieurs lignes, la derniere valeur non
vide rencontree fait foi : renseigner une seule de ses lignes suffit.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.groupes_clients.models import LIBELLES_LIENS, LIBELLES_PARTIES_LIEES

# Colonnes du classeur, et champ de la table `contreparties` qu'elles nourrissent.
COLONNE_NUMERO = "N_Centrale_risques"
COLONNE_SECTEUR = "Secteur_activite"
COLONNE_GROUPE = "Groupe_clients_lies"
COLONNE_NUMERO_GROUPE = "N_Centrale_risques_groupe"
COLONNE_LIEN = "Categorie_lien"
COLONNE_PARTIE_LIEE = "Partie_liee"

COLONNES_IDENTIFICATION: tuple[str, ...] = (
    COLONNE_NUMERO,
    COLONNE_SECTEUR,
    COLONNE_GROUPE,
    COLONNE_NUMERO_GROUPE,
    COLONNE_LIEN,
    COLONNE_PARTIE_LIEE,
)


def _texte(valeur: Any) -> str:
    return str(valeur).strip() if valeur not in (None, "") else ""


def _cle(libelle: str) -> str:
    """Normalise un libelle pour le comparer sans accents ni casse."""

    remplacements = str.maketrans("àâäéèêëîïôöùûüç", "aaaeeeeiioouuuc")
    return libelle.strip().casefold().translate(remplacements).replace("'", " ")


# Le classeur propose des libelles lisibles ; la base stocke des identifiants.
# La table est construite depuis les libelles officiels, pour qu'ajouter une
# categorie au modele suffise a la rendre importable.
_LIENS_PAR_LIBELLE = {_cle(libelle): code for code, libelle in LIBELLES_LIENS.items()}
_PARTIES_PAR_LIBELLE = {
    _cle(libelle): code for code, libelle in LIBELLES_PARTIES_LIEES.items()
}
# Les identifiants techniques restent acceptes : un classeur exporte puis
# reimporte ne doit pas perdre ses valeurs.
_LIENS_PAR_LIBELLE.update({_cle(code): code for code in LIBELLES_LIENS})
_PARTIES_PAR_LIBELLE.update({_cle(code): code for code in LIBELLES_PARTIES_LIEES})


def collecter_identifications(lignes: list[dict[str, Any]]) -> dict[str, dict[str, str]]:
    """Retient, par contrepartie, la derniere valeur non vide de chaque colonne."""

    identifications: dict[str, dict[str, str]] = {}
    for ligne in lignes:
        nom = _texte(ligne.get("Contrepartie"))
        if not nom:
            continue
        valeurs = {
            colonne: _texte(ligne.get(colonne))
            for colonne in COLONNES_IDENTIFICATION
            if _texte(ligne.get(colonne))
        }
        if not valeurs:
            continue
        identifications.setdefault(nom, {}).update(valeurs)
    return identifications


def appliquer_identifications(
    connection, identifications: dict[str, dict[str, str]]
) -> dict[str, int]:
    """Applique l'identification aux contreparties, et cree les groupes citees.

    Retourne le compte de contreparties mises a jour, de groupes crees et de
    valeurs non reconnues — ces dernieres sont ignorees plutot qu'ecrites
    telles quelles : une categorie de lien inventee ferait rejeter l'EP30.
    """

    horodatage = datetime.now(timezone.utc).isoformat(timespec="seconds")
    groupes_connus: dict[str, int] = {
        str(ligne["nom"]): int(ligne["id"])
        for ligne in connection.execute("SELECT id, nom FROM groupes_clients")
    }
    stats = {"contreparties": 0, "groupes_crees": 0, "valeurs_ignorees": 0}

    for nom, valeurs in identifications.items():
        affectations: dict[str, Any] = {}

        if valeurs.get(COLONNE_NUMERO):
            affectations["numero_centrale_risques"] = valeurs[COLONNE_NUMERO]
        if valeurs.get(COLONNE_SECTEUR):
            affectations["secteur_activite"] = valeurs[COLONNE_SECTEUR]

        lien = valeurs.get(COLONNE_LIEN)
        if lien:
            code = _LIENS_PAR_LIBELLE.get(_cle(lien))
            if code:
                affectations["categorie_lien"] = code
            else:
                stats["valeurs_ignorees"] += 1

        partie = valeurs.get(COLONNE_PARTIE_LIEE)
        if partie:
            code = _PARTIES_PAR_LIBELLE.get(_cle(partie))
            if code:
                affectations["categorie_partie_liee"] = code
            else:
                stats["valeurs_ignorees"] += 1

        nom_groupe = valeurs.get(COLONNE_GROUPE)
        if nom_groupe:
            identifiant = groupes_connus.get(nom_groupe)
            if identifiant is None:
                curseur = connection.execute(
                    """
                    INSERT INTO groupes_clients(
                        nom, numero_centrale_risques, cree_le, modifie_le
                    ) VALUES (?, ?, ?, ?)
                    """,
                    (
                        nom_groupe,
                        valeurs.get(COLONNE_NUMERO_GROUPE) or None,
                        horodatage,
                        horodatage,
                    ),
                )
                identifiant = int(curseur.lastrowid or 0)
                groupes_connus[nom_groupe] = identifiant
                stats["groupes_crees"] += 1
            elif valeurs.get(COLONNE_NUMERO_GROUPE):
                connection.execute(
                    """
                    UPDATE groupes_clients
                    SET numero_centrale_risques = ?, modifie_le = ?
                    WHERE id = ?
                    """,
                    (valeurs[COLONNE_NUMERO_GROUPE], horodatage, identifiant),
                )
            affectations["groupe_id"] = identifiant

        if not affectations:
            continue

        clauses = ", ".join(f"{champ} = ?" for champ in affectations)
        curseur = connection.execute(
            f"UPDATE contreparties SET {clauses}, modifie_le = ? WHERE nom = ?",
            list(affectations.values()) + [horodatage, nom],
        )
        stats["contreparties"] += curseur.rowcount

    return stats
