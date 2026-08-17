"""Suivi des participations de l'etablissement.

Alimente les etats EP34 et EP35 du FODEP, ainsi que les normes RA006 a RA008
de l'EP01. Tant que cette table est vide, ces trois limites prudentielles sont
declarees a zero, donc « CONFORME », sans qu'aucun encours ne l'ait verifie.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status

from app.core.bceao_calculations import calculate_fonds_propres
from app.core.natures_immobilisations import (
    NATURE_IMMO_EXPLOITATION,
    NATURE_IMMO_HORS_EXPLOITATION,
)
from app.participations.models import (
    LIBELLES_CATEGORIES,
    LIMITE_CAPITAL_EMETTEUR,
    LIMITE_FONDS_PROPRES_BASE,
    LIMITE_GLOBALE_FONDS_PROPRES_EFFECTIFS,
    LIMITE_IMMOBILISATIONS_ET_PARTICIPATIONS,
    LIMITE_IMMOBILISATIONS_HORS_EXPLOITATION,
    LimitePrudentielle,
    ParticipationCreate,
    ParticipationUpdate,
    ParticipationView,
    SyntheseParticipations,
    SyntheseParticipationsDetaillee,
)
from database.connection import database_manager


def _horodatage() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _vers_vue(ligne) -> ParticipationView:
    return ParticipationView(**dict(ligne))


def lister_participations() -> list[ParticipationView]:
    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT id, denomination, categorie, capital_entreprise,
                   montant_brut, montant_net, commentaire, cree_le, modifie_le
            FROM participations
            ORDER BY categorie, montant_net DESC, denomination
            """
        ).fetchall()
    return [_vers_vue(ligne) for ligne in lignes]


def creer_participation(payload: ParticipationCreate) -> ParticipationView:
    horodatage = _horodatage()
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            """
            INSERT INTO participations(
                denomination, categorie, capital_entreprise,
                montant_brut, montant_net, commentaire, cree_le, modifie_le
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                payload.denomination.strip(),
                payload.categorie,
                payload.capital_entreprise,
                payload.montant_brut,
                payload.montant_net,
                payload.commentaire,
                horodatage,
                horodatage,
            ),
        )
        identifiant = int(curseur.lastrowid or 0)
    return _lire_ou_404(identifiant)


def modifier_participation(
    identifiant: int, payload: ParticipationUpdate
) -> ParticipationView:
    champs = payload.model_dump(exclude_unset=True)
    if not champs:
        return _lire_ou_404(identifiant)

    affectations = ", ".join(f"{nom} = ?" for nom in champs)
    valeurs = list(champs.values()) + [_horodatage(), identifiant]
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            f"UPDATE participations SET {affectations}, modifie_le = ? WHERE id = ?",
            valeurs,
        )
        if curseur.rowcount == 0:
            raise _introuvable(identifiant)
    return _lire_ou_404(identifiant)


def supprimer_participation(identifiant: int) -> None:
    with database_manager.transaction() as connexion:
        curseur = connexion.execute(
            "DELETE FROM participations WHERE id = ?", (identifiant,)
        )
        if curseur.rowcount == 0:
            raise _introuvable(identifiant)


def _introuvable(identifiant: int) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail={
            "code": "PARTICIPATION_INTROUVABLE",
            "message": f"Aucune participation ne porte l'identifiant {identifiant}.",
        },
    )


def _lire_ou_404(identifiant: int) -> ParticipationView:
    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            """
            SELECT id, denomination, categorie, capital_entreprise,
                   montant_brut, montant_net, commentaire, cree_le, modifie_le
            FROM participations WHERE id = ?
            """,
            (identifiant,),
        ).fetchone()
    if ligne is None:
        raise _introuvable(identifiant)
    return _vers_vue(ligne)


def calculer_synthese(
    participations: list[ParticipationView],
    fonds_propres_t1: float,
    fonds_propres_effectifs: float,
) -> SyntheseParticipations:
    """Totaux par categorie et ratios des normes RA006 a RA008.

    Les limites de l'EP01 portent sur les seules entites commerciales : les
    participations dans les etablissements de credit, les assurances ou les
    societes immobilieres relevent d'autres dispositions.
    """

    totaux = {categorie: 0.0 for categorie in LIBELLES_CATEGORIES}
    for participation in participations:
        totaux[participation.categorie] += participation.montant_net

    commerciales = [
        participation
        for participation in participations
        if participation.categorie == "entite_commerciale"
    ]
    total_commerciales = sum(participation.montant_net for participation in commerciales)

    # Limite individuelle rapportee au capital de l'emetteur : le formulaire
    # retient la souscription (montant brut) au numerateur, colonne d = b / a.
    parts_capital = [
        participation.montant_brut / participation.capital_entreprise
        for participation in commerciales
        if participation.capital_entreprise > 0
    ]
    # Limite individuelle rapportee aux fonds propres de base : montant libere.
    parts_t1 = [
        participation.montant_net / fonds_propres_t1
        for participation in commerciales
        if fonds_propres_t1 > 0
    ]

    return SyntheseParticipations(
        totaux_par_categorie=totaux,
        total_general=sum(totaux.values()),
        total_entites_commerciales=total_commerciales,
        ratio_max_capital_emetteur=max(parts_capital, default=0.0),
        ratio_max_fonds_propres_t1=max(parts_t1, default=0.0),
        ratio_global_fonds_propres_effectifs=(
            total_commerciales / fonds_propres_effectifs
            if fonds_propres_effectifs > 0
            else 0.0
        ),
    )


# ─── Synthese affichee par les ecrans ────────────────────────────────────────


def _flottant(valeur) -> float:
    try:
        return float(valeur or 0.0)
    except (TypeError, ValueError):
        return 0.0


def _fonds_propres() -> tuple[float, float, str | None]:
    """Fonds propres de base T1 et fonds propres effectifs les plus recents.

    Ce sont les denominateurs de quatre des cinq limites. Sans eux, les
    limites ne sont pas « respectees » : elles ne sont pas mesurables, et
    l'ecran doit le dire plutot que d'afficher un zero rassurant.
    """

    with database_manager.read_connection() as connexion:
        ligne = connexion.execute(
            "SELECT * FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1"
        ).fetchone()
    if ligne is None:
        return 0.0, 0.0, None
    donnees = dict(ligne)
    calcul = calculate_fonds_propres(donnees)
    date = donnees.get("date_analyse")
    return (
        _flottant(calcul.get("t1")),
        _flottant(calcul.get("total_capital")),
        str(date) if date else None,
    )


def _immobilisations() -> tuple[float, float]:
    """Immobilisations nettes : total, et part hors exploitation.

    Meme lecture que l'export pour les etats EP36 et EP37, aux memes natures
    d'actifs : les deux limites qui additionnent immobilisations et
    participations doivent porter sur les memes montants ici et la.
    """

    with database_manager.read_connection() as connexion:
        lignes = connexion.execute(
            """
            SELECT a.type_actif AS nature, SUM(e.ead) AS net
            FROM exposition_autre_actif a
            JOIN expositions e ON e.id = a.exposition_id
            WHERE a.type_actif IN (?, ?)
            GROUP BY a.type_actif
            """,
            (NATURE_IMMO_EXPLOITATION, NATURE_IMMO_HORS_EXPLOITATION),
        ).fetchall()

    total = 0.0
    hors_exploitation = 0.0
    for ligne in lignes:
        montant = _flottant(ligne["net"])
        total += montant
        if str(ligne["nature"]) == NATURE_IMMO_HORS_EXPLOITATION:
            hors_exploitation += montant
    return total, hors_exploitation


def _limite(
    *,
    code: str,
    libelle: str,
    etat: str,
    numerateur: float,
    numerateur_libelle: str,
    denominateur: float,
    denominateur_libelle: str,
    limite: float,
    concerne: str | None = None,
) -> LimitePrudentielle:
    mesurable = denominateur > 0
    observe = numerateur / denominateur if mesurable else 0.0
    return LimitePrudentielle(
        code=code,
        libelle=libelle,
        etat=etat,
        numerateur=round(numerateur, 2),
        numerateur_libelle=numerateur_libelle,
        denominateur=round(denominateur, 2),
        denominateur_libelle=denominateur_libelle,
        observe=round(observe, 4),
        limite=limite,
        mesurable=mesurable,
        # Une limite non mesurable n'est pas respectee : elle est inconnue.
        # La declarer respectee reproduirait le defaut que ce suivi corrige.
        respectee=mesurable and observe <= limite,
        excedent=round(max(0.0, numerateur - limite * denominateur), 2) if mesurable else 0.0,
        concerne=concerne,
    )


def synthese_detaillee() -> SyntheseParticipationsDetaillee:
    """Etat des participations et des cinq limites qui les encadrent.

    Trois limites ne portent que sur les entites commerciales (RA006 a RA008).
    Les deux dernieres (RA009 et RA010) additionnent les participations aux
    immobilisations : elles relient ce suivi aux autres actifs importes.
    """

    participations = lister_participations()
    fonds_propres_t1, fonds_propres_effectifs, date_fonds_propres = _fonds_propres()
    immobilisations_nettes, immobilisations_hors_exploitation = _immobilisations()

    synthese = calculer_synthese(
        participations,
        fonds_propres_t1=fonds_propres_t1,
        fonds_propres_effectifs=fonds_propres_effectifs,
    )

    commerciales = [
        participation
        for participation in participations
        if participation.categorie == "entite_commerciale"
    ]

    # La participation qui porte la limite : celle dont la part du capital de
    # l'emetteur est la plus forte, puis celle dont le montant libere l'est.
    avec_capital = [p for p in commerciales if p.capital_entreprise > 0]
    plus_forte_capital = max(
        avec_capital,
        key=lambda p: p.montant_brut / p.capital_entreprise,
        default=None,
    )
    plus_forte_nette = max(commerciales, key=lambda p: p.montant_net, default=None)

    participations_immobilieres = synthese.totaux_par_categorie.get(
        "societe_immobiliere", 0.0
    )

    limites = [
        _limite(
            code="RA006",
            libelle="Participation la plus forte dans une entité commerciale",
            etat="EP35",
            numerateur=plus_forte_capital.montant_brut if plus_forte_capital else 0.0,
            numerateur_libelle="Souscription (montant brut)",
            denominateur=(
                plus_forte_capital.capital_entreprise if plus_forte_capital else 0.0
            ),
            denominateur_libelle="Capital de l'entreprise émettrice",
            limite=LIMITE_CAPITAL_EMETTEUR,
            concerne=plus_forte_capital.denomination if plus_forte_capital else None,
        ),
        _limite(
            code="RA007",
            libelle="Participation la plus forte rapportée aux fonds propres",
            etat="EP35",
            numerateur=plus_forte_nette.montant_net if plus_forte_nette else 0.0,
            numerateur_libelle="Montant libéré net de provisions",
            denominateur=fonds_propres_t1,
            denominateur_libelle="Fonds propres de base T1",
            limite=LIMITE_FONDS_PROPRES_BASE,
            concerne=plus_forte_nette.denomination if plus_forte_nette else None,
        ),
        _limite(
            code="RA008",
            libelle="Total des participations dans les entités commerciales",
            etat="EP35",
            numerateur=synthese.total_entites_commerciales,
            numerateur_libelle="Participations dans les entités commerciales",
            denominateur=fonds_propres_effectifs,
            denominateur_libelle="Fonds propres effectifs",
            limite=LIMITE_GLOBALE_FONDS_PROPRES_EFFECTIFS,
        ),
        _limite(
            code="RA009",
            libelle="Immobilisations hors exploitation et participations immobilières",
            etat="EP36",
            numerateur=immobilisations_hors_exploitation + participations_immobilieres,
            numerateur_libelle=(
                "Immobilisations hors exploitation + participations immobilières"
            ),
            denominateur=fonds_propres_t1,
            denominateur_libelle="Fonds propres de base T1",
            limite=LIMITE_IMMOBILISATIONS_HORS_EXPLOITATION,
        ),
        _limite(
            code="RA010",
            libelle="Immobilisations et participations",
            etat="EP37",
            numerateur=immobilisations_nettes + synthese.total_general,
            numerateur_libelle="Immobilisations nettes + total des participations",
            denominateur=fonds_propres_effectifs,
            denominateur_libelle="Fonds propres effectifs",
            limite=LIMITE_IMMOBILISATIONS_ET_PARTICIPATIONS,
        ),
    ]

    alertes: list[str] = []
    if not participations:
        alertes.append(
            "Aucune participation enregistrée : l'EP01 déclare « CONFORME » "
            "les limites RA006 à RA008 sans qu'aucun encours ne l'ait vérifié."
        )
    if fonds_propres_t1 <= 0 or fonds_propres_effectifs <= 0:
        alertes.append(
            "Aucun fonds propres saisi : quatre limites sur cinq n'ont pas de "
            "dénominateur et restent non mesurées. Renseignez les fonds "
            "propres pour qu'elles se calculent."
        )
    sans_capital = [p for p in commerciales if p.capital_entreprise <= 0]
    if sans_capital:
        alertes.append(
            f"{len(sans_capital)} participation(s) commerciale(s) sans capital "
            "de l'émetteur : leur part du capital ne peut pas être calculée, "
            "la limite RA006 ne les voit pas."
        )
    if not immobilisations_nettes:
        alertes.append(
            "Aucune immobilisation importée : les limites RA009 et RA010 ne "
            "portent que sur les participations, pas sur leur assiette "
            "complète."
        )
    elif not immobilisations_hors_exploitation:
        # Meme constat que l'anomalie de l'EP36 : une limite nulle faute
        # d'actif classe sous cette nature n'est pas une limite respectee.
        alertes.append(
            "Aucune immobilisation « hors exploitation » n'est déclarée : la "
            "limite RA009 ne porte que sur les participations immobilières. "
            "Classez ces actifs sous cette nature à l'import si "
            "l'établissement en détient."
        )

    return SyntheseParticipationsDetaillee(
        nombre=len(participations),
        nombre_entites_commerciales=len(commerciales),
        total_general=round(synthese.total_general, 2),
        total_entites_commerciales=round(synthese.total_entites_commerciales, 2),
        totaux_par_categorie={
            categorie: round(montant, 2)
            for categorie, montant in synthese.totaux_par_categorie.items()
        },
        libelles_categories=LIBELLES_CATEGORIES,
        fonds_propres_t1=round(fonds_propres_t1, 2),
        fonds_propres_effectifs=round(fonds_propres_effectifs, 2),
        date_fonds_propres=date_fonds_propres,
        immobilisations_nettes=round(immobilisations_nettes, 2),
        immobilisations_hors_exploitation_nettes=round(
            immobilisations_hors_exploitation, 2
        ),
        limites=limites,
        alertes=alertes,
    )
