"""Dispositions transitoires sur les fonds propres : lecture et calcul.

Bale III a rendu inadmissibles certains elements de fonds propres au
1er janvier 2018 et les retire progressivement. L'EP04 porte ce calcul ; quatre
de ses lignes retombent dans l'EP03.

Ce module tient les montants et les rapprochements que le formulaire annonce
sans les faire. Le taux de retrait, lui, n'est pas ici : la BCEAO l'imprime sur
l'etat, et c'est l'export qui l'y relit -- comme les ponderations de l'EP11.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from app.dispositions_transitoires.models import (
    DispositionsTransitoiresUpdate,
    DispositionsTransitoiresView,
)
from database.connection import database_manager

CHAMPS_SAISIS = (
    "part_capital_non_admissible",
    "provisions_reglementees",
    "fonds_affectes",
    "cet1_en_circulation",
    "cet1_eligible_at1",
    "cet1_eligible_t2_autres",
    "cet1_eligible_t2_provisions",
    "cet1_eligible_t2_fonds_affectes",
    "cet1_exclu",
    "dettes_subordonnees_2018",
    "part_dettes_non_admissible",
    "ecarts_reevaluation",
    "autres_t2_non_admissibles",
    "t2_en_circulation",
)

COLONNES = ("exercice", *CHAMPS_SAISIS, "commentaire", "cree_le", "modifie_le")


def _horodatage() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def lire_dispositions(exercice: int | None = None) -> DispositionsTransitoiresView | None:
    """Les dispositions d'un exercice, ou du plus recent si aucun n'est demande.

    Rend `None` plutot qu'un enregistrement a zero : « rien n'a ete saisi » et
    « tout vaut zero » ne se declarent pas de la meme facon, et c'est l'appelant
    qui doit pouvoir le dire.
    """

    requete = f"SELECT {', '.join(COLONNES)} FROM dispositions_transitoires"
    parametres: tuple = ()
    if exercice is None:
        requete += " ORDER BY exercice DESC LIMIT 1"
    else:
        requete += " WHERE exercice = ?"
        parametres = (exercice,)

    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(requete, parametres).fetchone()
    return DispositionsTransitoiresView(**dict(ligne)) if ligne else None


def enregistrer_dispositions(
    payload: DispositionsTransitoiresUpdate,
) -> DispositionsTransitoiresView:
    """Cree ou remplace les dispositions d'un exercice.

    Un exercice, un enregistrement : l'index unique le garantit, l'upsert le
    respecte. Deux corrections du meme millesime se remplacent, elles ne
    s'empilent pas.
    """

    horodatage = _horodatage()
    valeurs = [payload.exercice]
    valeurs += [getattr(payload, champ) for champ in CHAMPS_SAISIS]
    valeurs += [payload.commentaire, horodatage, horodatage]

    affectations = ", ".join(f"{champ} = excluded.{champ}" for champ in CHAMPS_SAISIS)
    with database_manager.transaction() as connexion:
        connexion.execute(
            f"""
            INSERT INTO dispositions_transitoires({', '.join(COLONNES)})
            VALUES ({', '.join('?' * len(COLONNES))})
            ON CONFLICT(exercice) DO UPDATE SET
                {affectations},
                commentaire = excluded.commentaire,
                modifie_le  = excluded.modifie_le
            """,
            valeurs,
        )
    resultat = lire_dispositions(payload.exercice)
    assert resultat is not None  # l'upsert vient de l'ecrire
    return resultat


def supprimer_dispositions(exercice: int) -> None:
    with database_manager.transaction() as connexion:
        connexion.execute(
            "DELETE FROM dispositions_transitoires WHERE exercice = ?", (exercice,)
        )


# ─── Le calcul de l'etat ─────────────────────────────────────────────────────


@dataclass(frozen=True)
class CalculEp04:
    """Les sept lignes que l'EP04 fait calculer, et ce qui en decoule.

    Le formulaire imprime ses formules en tete de ligne mais attend le
    resultat : « a l'exception de l'EP01, le formulaire ne contient aucune
    formule » (notice, § 3.3).
    """

    #: (f) = c + d + e — total des elements de CET1 non admissibles.
    total_cet1_non_admissible: float
    #: (g) = f x a — montant maximal qui peut encore etre inclus.
    plafond_cet1: float
    #: (i) = min(g, h) — FPI07, ce que le CET1 conserve.
    cet1_reconnu: float
    #: DT008 — total reclasse en T2, somme de ses trois « dont ».
    total_eligible_t2: float
    #: (n) = k + l + m — total des elements de T2 non admissibles.
    total_t2_non_admissible: float
    #: (o) = n x a — montant maximal qui peut encore etre inclus.
    plafond_t2: float
    #: (q) = min(o, p) — FPI34, ce que le T2 conserve.
    t2_reconnu: float

    def report_ep03(self, saisies: DispositionsTransitoiresView) -> dict[str, float]:
        """Les quatre lignes que l'EP03 reprend de l'EP04.

        FPI35 et FPI36 n'y sont pas, bien que l'EP04 les detaille : l'EP03 les
        declare de son cote, a partir des provisions generales que
        l'application enregistre. Les ecrire ici en ferait deux valeurs pour un
        meme code DISPRU, et la plate-forme lirait une declaration qui se
        contredit. L'export le signale au lieu de trancher a la place du
        declarant.
        """

        return {
            "FPI07": self.cet1_reconnu,
            "FPI25": saisies.cet1_eligible_at1,
            "FPI33": saisies.cet1_eligible_t2_autres,
            "FPI34": self.t2_reconnu,
        }


def calculer_ep04(
    saisies: DispositionsTransitoiresView | None, taux_de_retrait: float
) -> CalculEp04:
    """Applique les formules de l'EP04 aux montants saisis.

    Sans saisie, tout vaut zero : c'est ce que declare un etablissement qui ne
    detient aucun instrument en retrait progressif. La difference entre ce zero
    et celui d'avant tient a ce que l'export en dit.
    """

    if saisies is None:
        return CalculEp04(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

    total_cet1 = (
        saisies.part_capital_non_admissible
        + saisies.provisions_reglementees
        + saisies.fonds_affectes
    )
    plafond_cet1 = total_cet1 * taux_de_retrait
    total_t2 = (
        saisies.part_dettes_non_admissible
        + saisies.ecarts_reevaluation
        + saisies.autres_t2_non_admissibles
    )
    plafond_t2 = total_t2 * taux_de_retrait

    return CalculEp04(
        total_cet1_non_admissible=total_cet1,
        plafond_cet1=plafond_cet1,
        # « i = min(g, h) » : le stock d'origine plafonne par le taux de
        # retrait, mais on ne reconnait jamais plus que ce qui circule encore.
        cet1_reconnu=min(plafond_cet1, saisies.cet1_en_circulation),
        total_eligible_t2=(
            saisies.cet1_eligible_t2_autres
            + saisies.cet1_eligible_t2_provisions
            + saisies.cet1_eligible_t2_fonds_affectes
        ),
        total_t2_non_admissible=total_t2,
        plafond_t2=plafond_t2,
        t2_reconnu=min(plafond_t2, saisies.t2_en_circulation),
    )
